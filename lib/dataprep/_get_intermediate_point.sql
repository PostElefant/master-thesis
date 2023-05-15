--Calculate radius from distance between points
--create buffer with this radius around start and end point
--see where the two buffers meet
--select the point which is closer to the edge point
--take the three points, start-, intermediate- and endpoint as input for function CreateCurve
--then create a ConvexHull around this line, and the buffers around the start and end points.

DROP FUNCTION IF EXISTS get_intermediate_point(geometry, integer, geometry);
CREATE OR REPLACE FUNCTION get_intermediate_point(geometry, integer, geometry) 
RETURNS geometry AS $$
	DECLARE 
		turnuse_geom ALIAS FOR $1;
		node_id ALIAS FOR $2;
		intersection_p_linearuses ALIAS FOR $3; --point geometry
		distance_p1 double precision;
		distance_p2 double precision;
		intersection_p1 geometry;
		intersection_p2 geometry;
		side_p1 double precision;
		side_p2 double precision;
		side_int_p double precision;
		x double precision;
		y double precision;
		node_geom geometry;
	
BEGIN
	RAISE NOTICE 'srid turnuse_geom: %', st_srid(turnuse_geom);

WITH
   --get the radius of the Exterior Rings that are to be built 
   --by determining the distance between start and endpoint of turnuse
   radius AS ( 
      SELECT ST_Distance(ST_Transform(ST_StartPoint(turnuse_geom),31259), 
						 ST_Transform(ST_EndPoint(turnuse_geom),31259))*0.505 as t),
	
	--building buffers with the radius r and extracting their exterior rings 
	-- to get circles around each point. 
	buffers AS (
		SELECT ST_ExteriorRing(ST_Buffer(ST_Transform(ST_StartPoint(turnuse_geom), 
													  31259),r.t)) as st, 
		ST_ExteriorRing(ST_Buffer(ST_Transform(ST_EndPoint(turnuse_geom),31259),r.t)) 
		as en
   		FROM radius r),
	
	--finding out, where the circles around the points intersect
	intersectionpoints AS(	
		SELECT (ST_Dump(ST_Intersection(st , en))).geom 
		FROM buffers), --delivers multipoints
	
	--dividing the multipoints and arranging it to a table  
	-- that holds the fid, the first and the second point
	dividedpoints AS (	
		SELECT DISTINCT ip.geom as geom1, ip2.geom as geom2
		FROM intersectionpoints ip, intersectionpoints ip2
		WHERE ST_AsText(ip.geom) < ST_AsText(ip2.geom)
    )
	
	--selecting the points in variables
	SELECT INTO distance_p1, distance_p2, intersection_p1, intersection_p2, 
	side_p1, side_p2, side_int_p, node_geom
		--take the elongated linearuse to determine the intermediate point
		ST_Distance(p.geom1,intersection_p_linearuses), 
		ST_Distance(p.geom2, intersection_p_linearuses),
		p.geom1, p.geom2,
		side_of_line(turnuse_geom, p.geom1), side_of_line(turnuse_geom, p.geom2), 
		side_of_line(turnuse_geom, intersection_p_linearuses),
		ST_Transform(n.geom,31259)
	
	FROM dividedpoints p, node_ogd_aoi n WHERE n.objectid = node_id;
	
	
	RAISE NOTICE 'intersection_p1: %, intersection_p2: %, 
	sol1: %, sol2: %, solInt: %', 
	ST_AsText(intersection_p1), ST_AsText(intersection_p2), 
	side_p1, side_p2, side_int_p;
		
	IF(ROUND(side_p1) = ROUND(side_int_p)) THEN
		RAISE NOTICE 'ip1: %', ST_AsText(intersection_p1);
		RETURN intersection_p1;
	ELSIF(ROUND(side_p2) = ROUND(side_int_p)) THEN
		RAISE NOTICE 'ip2: %', ST_AsText(intersection_p2);
		RETURN intersection_p2;
	ELSIF(side_int_p IS NULL) THEN
		x := ST_X(intersection_p2)+(ST_X(intersection_p1)-ST_X(intersection_p2))/2;
		RAISE NOTICE 'X: %', x;
		y := ST_Y(intersection_p2)+(ST_Y(intersection_p1)-ST_Y(intersection_p2))/2;
		RAISE NOTICE 'Y: %', y; 
		RETURN ST_PointFromText('POINT('||x||' '||y||')', 31259); 
	ELSE
		RAISE NOTICE 'NODE is used';
		RETURN node_geom;
	

	END IF;

  END;
$$ LANGUAGE 'plpgsql';
