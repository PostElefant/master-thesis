------ 1 - ENVIRONMENT -------------------------------------
--------- 1.1 URBAN INTERSECTION? --------------------------
DROP FUNCTION IF EXISTS check_urban(integer);
CREATE OR REPLACE FUNCTION check_urban(integer) 
RETURNS boolean AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	urban boolean;
	no_urban_links integer;
 
  BEGIN
	-- get number of links that are part of a round about (formofway = 4)
  	no_urban_links := (SELECT COUNT(l.*) FROM gip_linknetz_ogd_aoi l 
					   WHERE (l.from_node = node_id OR l.to_node = node_id) AND l.urban = 1);
	
	IF (no_urban_links > 0) THEN
		urban = TRUE; -- if one or more links with fow = 4 were found and counted in no_ra_links, the function returns true
	ELSE
		urban = FALSE; -- else, false is returned
	END IF;
	
	return urban; -- return whether the intersection belongs to a round about or not.

  END;
$$ LANGUAGE 'plpgsql';	


------ 1.2 TRAIN IN ENVIRONMENT? ---------------------------
DROP FUNCTION IF EXISTS check_rails(integer);
CREATE OR REPLACE FUNCTION check_rails(integer) 
RETURNS boolean AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	rails boolean;
	no_train_links integer;
	radius integer; 
 
  BEGIN
	radius := 5; -- according to Harris et al. (2013)
	-- get number of edges (which are rails) that are in the 
	-- radius of the intersection which was determined
  	no_train_links := (
						SELECT COUNT(e.*) 
						FROM edge_ogd_aoi e, node_ogd_aoi n 
						WHERE n.objectid = node_id AND
							   (e.frc = 101 OR e.frc = 102 OR e.frc = 103) AND
							   ST_Intersects(ST_Buffer(ST_Transform(n.geom, 31256), radius),
											 ST_Transform(e.geom, 31256))
					);
	
	IF (no_train_links > 0) THEN
		rails = TRUE; -- if one or more edges are trail-related, true is returned
	ELSE
		rails = FALSE; -- else, false is returned
	END IF;
	
	return rails; -- return whether the intersection belongs to a round about or not.

  END;
$$ LANGUAGE 'plpgsql';	


------ 2 - TRAFFIC RULES -----------------------------------

------ 2.1.1 - TRAFFIC LIGHTS NEAREST NEIGHBOR -------------
-- helps to connect traffic lights and intersection
-- this function looks for the nearest neighbor of traffic lights in the AOI 
-- (within a 15 meter radius). If it found a nearest neighbor, it writes the 
-- intersection id into the traffic light's table in the attribute node_id.
DROP FUNCTION IF EXISTS nearest_neighbour_tl();
CREATE OR REPLACE FUNCTION nearest_neighbour_tl() 
RETURNS void AS $$ 
  DECLARE
	 no_lights INTEGER;
	 l_node_id BIGINT;
	 
  BEGIN
  
  	no_lights := (SELECT COUNT(*) FROM rd_traffic_lights);
	
	FOR q in 1..no_lights LOOP
  	
		l_node_id := (SELECT n.objectid
		FROM rd_traffic_lights tl, node_ogd_aoi n
		WHERE tl.id = q AND ST_DWithin(ST_Transform(n.geom, 31256), ST_Transform(tl.geom, 31256), 15)
		ORDER BY ST_Transform(n.geom, 31256) <-> ST_Transform(tl.geom, 31256)
		LIMIT 1);
		
		UPDATE rd_traffic_lights tl SET node_id = l_node_id WHERE tl.id = q;
		
	END LOOP;

  END;
$$ LANGUAGE 'plpgsql';	

------------ ADDITIONAL traffic light function ------------
---- 2.1 - check whether there is a traffic light "connected" to the intersection
DROP FUNCTION IF EXISTS check_traffic_lights(integer);
CREATE OR REPLACE FUNCTION check_traffic_lights(integer) 
RETURNS boolean AS $$ 
  DECLARE
  	nodeid ALIAS FOR $1;
	tl boolean;
 
  BEGIN
  
  	IF ((SELECT COUNT(*) FROM rd_traffic_lights tl WHERE tl.node_id = nodeid) > 0) THEN 
		tl = TRUE;
	ELSE 
		tl = FALSE;
	END IF;

	return tl; -- return whether the intersection belongs to a round about or not.

  END;
$$ LANGUAGE 'plpgsql';	



------ 3 - GEOMETRY -------------------------------------

------ 3.1 - intersection legs: can be easily determined with a single 
-- SQL-Statement. Therefore, it is directly executed in get_global_risk

------ 3.2 - angle of intersection: is classified as of little importance and the
-- literature is unclear in what is meant when speaking about intersection angle


------ 4 - BEHAVIOR ------------------------------------

------ 4.1 - SPEED: get the highest speed that "goes into" the intersection
DROP FUNCTION IF EXISTS get_speed(integer);
CREATE OR REPLACE FUNCTION get_speed(integer) 
RETURNS integer AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	speed integer;
	no_links integer;
	tmp_speed integer;
	frc integer; -- road category (function of road) is used in case no speed could be found
 
  BEGIN
  	no_links := (SELECT COUNT(l.*) FROM gip_linknetz_ogd_aoi l WHERE l.from_node = node_id OR l.to_node = node_id);
	speed := -2;
				 
	FOR q in 1..no_links LOOP
		-- check both the lanes in and against the driving direction for the maximum 
		-- speed, store it temporarily in tmp_speed. 
		-- if it is the highest value that is found, it gets stored in "speed"
		tmp_speed := (SELECT vmax_car_t FROM gip_linknetz_ogd_aoi l 
			 			WHERE l.from_node = node_id OR l.to_node = node_id 
			 			ORDER BY link_id LIMIT 1 OFFSET (q-1));
		IF (speed < tmp_speed) THEN
			speed := tmp_speed;
		END IF;
				 
		tmp_speed := (SELECT vmax_car_b FROM gip_linknetz_ogd_aoi l 
			 			WHERE l.from_node = node_id OR l.to_node = node_id 
			 			ORDER BY link_id LIMIT 1 OFFSET (q-1));
		IF (speed < tmp_speed) THEN
			speed := tmp_speed;
		END IF;
				 
	END LOOP;
	
	-- in case, none of the connected links do have attributes regarding the 
	-- maximum speed (meaning that "speed" is still -2), the average speed is used:
	IF (speed = -2) THEN
		FOR q in 1..no_links LOOP
			tmp_speed := (SELECT speedcar_t FROM gip_linknetz_ogd_aoi l 
				 			WHERE l.from_node = node_id OR l.to_node = node_id 
				 			ORDER BY link_id LIMIT 1 OFFSET (q-1));
			IF (speed < tmp_speed) THEN
				speed := tmp_speed;
			END IF;
					 
			tmp_speed := (SELECT speedcar_b FROM gip_linknetz_ogd_aoi l 
				 			WHERE l.from_node = node_id OR l.to_node = node_id 
				 			ORDER BY link_id LIMIT 1 OFFSET (q-1));
			IF (speed < tmp_speed) THEN
				speed := tmp_speed;
			END IF;
		END LOOP;
	END IF;
	
	-- if this also does not get any results, we'll have to rely on the road type.
	IF (speed = -2) THEN 
		FOR q in 1..no_links LOOP -- loop through the link connected to the intersection
			-- load the road category in the variable "frc"
			frc := (SELECT l.frc FROM gip_linknetz_ogd_aoi l WHERE l.from_node = node_id OR l.to_node = node_id ORDER BY link_id LIMIT 1 OFFSET (q-1));
			CASE
--- the cases don't necessarily produce the same results as the speed attributes
				WHEN frc IN (-1, 10, 20, 21, 22, 24, 25, 31, 45, 46, 47, 48, 101, 102, 103, 115, 200, 300)
					THEN tmp_speed := 0;
				WHEN frc IN (107)
					THEN tmp_speed := 10;
				WHEN frc IN (105, 106, 301)
					THEN tmp_speed := 30;
				WHEN frc IN (7, 8, 11, 12, 98, 99)
					THEN tmp_speed := 50;
				WHEN frc IN (5, 6)
					THEN tmp_speed := 70;
				WHEN frc IN (2, 3, 4)
					THEN tmp_speed := 100;
				WHEN frc IN (0, 1)
					THEN tmp_speed := 130;
			END CASE;
			IF (tmp_speed > speed) THEN speed := tmp_speed; END IF;
		END LOOP;
	END IF;
	
	RETURN speed;

  END;
$$ LANGUAGE 'plpgsql';	



----------- STREET CHARACTERISTICS -------------------------
-- 5.1.1 - Number of lanes -> returns the number of turn relation (type car)
-- that are crossed
DROP FUNCTION IF EXISTS car_lanes_crossed(integer);
CREATE OR REPLACE FUNCTION car_lanes_crossed(integer) 
RETURNS integer AS $$ 
  DECLARE
  	turnuse_fid ALIAS FOR $1;
	no_car_lanes integer;
	car_cross_counter integer;
	original_turnuse iplateau%ROWTYPE;
	turnuses_that_crosses geometry;
	turnuses_id integer;
 
  BEGIN
  	car_cross_counter = 0;
	no_car_lanes := (SELECT COUNT(*) FROM iplateau 
					 WHERE basetype = 1 AND fid <> turnuse_fid);
	SELECT INTO original_turnuse ip.* FROM iplateau ip WHERE ip.fid = turnuse_fid;
	
	FOR q IN 1..no_car_lanes LOOP
		turnuses_that_crosses := (SELECT turnuse_geom FROM iplateau 
								  WHERE basetype = 1 ORDER BY fid LIMIT 1 OFFSET q-1);
		turnuses_id := (SELECT fid FROM iplateau WHERE basetype = 1 
						ORDER BY fid LIMIT 1 OFFSET q-1);
		
		IF ST_Crosses(original_turnuse.turnuse_geom, turnuses_that_crosses) IS TRUE THEN
			car_cross_counter := car_cross_counter + 1;
			RAISE NOTICE 'Crossed car turnuse. FID = %', turnuses_id;
		END IF;
	END LOOP;
	
  	 -- returns the number of car lanes the bike lane's crossing
	return car_cross_counter;

  END;
$$ LANGUAGE 'plpgsql';	


-- 5.1.2 - Number of lanes 
-- -> returns the number of bike/pedestrian turnuses crossed 
DROP FUNCTION IF EXISTS bike_lanes_crossed(integer);
CREATE OR REPLACE FUNCTION bike_lanes_crossed(integer) 
RETURNS integer AS $$ 
  DECLARE
  	turnuse_fid ALIAS FOR $1;
	no_bike_lanes integer;
	bike_cross_counter integer;
	original_turnuse iplateau%ROWTYPE;
	turnuses_that_crosses geometry;
	turnuses_id integer;
 
  BEGIN
  	bike_cross_counter = 0;
	no_bike_lanes := (SELECT COUNT(*) FROM iplateau 
					  WHERE basetype <> 1 AND fid <> turnuse_fid); 
	SELECT INTO original_turnuse ip.* FROM iplateau ip WHERE ip.fid = turnuse_fid;
	
	FOR q IN 1..no_bike_lanes LOOP
		turnuses_that_crosses := (SELECT turnuse_geom FROM iplateau
								  WHERE basetype <> 1 ORDER BY fid LIMIT 1 OFFSET q-1);
		turnuses_id := (SELECT fid FROM iplateau WHERE basetype <> 1 
						ORDER BY fid LIMIT 1 OFFSET q-1); 
		
		IF ST_Crosses(original_turnuse.turnuse_geom, turnuses_that_crosses) IS TRUE THEN
			bike_cross_counter := bike_cross_counter + 1;
			RAISE NOTICE 'Crossed bike turnuse. FID = %', turnuses_id;
		END IF;
	END LOOP;
	
  	
	return bike_cross_counter; -- returns the number of car lanes the bike lane's crossing

  END;
$$ LANGUAGE 'plpgsql';	



-- 5.2 - Gradient
DROP FUNCTION IF EXISTS check_gradient_slope(bigint);
CREATE OR REPLACE FUNCTION check_gradient_slope(bigint) 
RETURNS real AS $$ 
  DECLARE
  	edge_id ALIAS FOR $1;
	no_linked_nodes integer;
	links gip_linknetz_ogd_aoi%ROWTYPE;
	distance real;
	height1 real;
	node_id2 bigint;
	node1 node_ogd_aoi%ROWTYPE;
	node2 node_ogd_aoi%ROWTYPE;
	height2 real;
	pos_height_diff real;
	height_diff real;
	gradient real;
 
  BEGIN
  	-- get the nodes which height is need
  	SELECT INTO node1 n.* FROM node_ogd_aoi n, edge_ogd_aoi e WHERE e.nodefromid = n.objectid AND e.objectid = edge_id;
	SELECT INTO node2 n.* FROM node_ogd_aoi n, edge_ogd_aoi e WHERE e.nodetoid = n.objectid AND e.objectid = edge_id;
	
	-- calculate distance between the two nodes
	distance := ST_Distance(ST_Transform(node1.geom, 31256), ST_Transform(node2.geom, 31256));
	
	-- get the heights of the two nodes
	height1 := (SELECT ST_Value(r.rast, ST_Transform(n.geom, 31256), true)
			    FROM node_ogd_aoi n, raster_dem_aoi r
			    WHERE n.objectid = node1.objectid ORDER BY 1 asc LIMIT 1);
	RAISE NOTICE 'Craziness?';
	height2 := (SELECT ST_Value(r.rast, ST_Transform(n.geom, 31256), true)
			    FROM node_ogd_aoi n, raster_dem_aoi r
			    WHERE n.objectid = node2.objectid ORDER BY 1 asc LIMIT 1);
	RAISE NOTICE 'craziness2?';
				
	pos_height_diff := (SELECT ABS(height1 - height2));
	
	-- calculate the gradient/slope in percents
	gradient := (pos_height_diff / distance);
			
	return gradient;
	
  END;
$$ LANGUAGE 'plpgsql';	




-- 5.4 - Street Types - goes through each of the edges that lead to the node. 
-- if one of them is counted as major street (hoeherrangig), 
-- the function returns immediately 1 - otherwise it returns 0.
DROP FUNCTION IF EXISTS check_streettypes(bigint);
CREATE OR REPLACE FUNCTION check_streettypes(bigint) 
RETURNS boolean AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	no_edges integer;
	edge edge_ogd_aoi%ROWTYPE;
 
  BEGIN
	-- get number of edges connected to the node
  	no_edges := (SELECT COUNT(e.*) FROM edge_ogd_aoi e WHERE e.nodefromid = node_id OR e.nodetoid = node_id);
	
	FOR q IN 1..no_edges LOOP
		SELECT INTO edge e.* FROM edge_ogd_aoi e
		WHERE e.nodefromid = node_id OR e.nodetoid = node_id
		ORDER BY e.objectid
		LIMIT 1
		OFFSET q-1;
		
		-- the major roads are those where the edgecategory is A, S, B or L 
		-- (GIP Documentation, p. 47)
		IF edge.edgecat IN ('A', 'S', 'L', 'B') THEN 
			RAISE NOTICE '1 is returned -> major road';
			return true;
		END IF;		
	
	END LOOP;
	
	RAISE NOTICE '0 is returned -> just minor roads';
	return false; -- return whether the intersection belongs to a round about or not.

  END;
$$ LANGUAGE 'plpgsql';	


-- 5.5 - Street Condition




----------- ROUND ABOUT -------------------------------

-- 6.1 - calculates the inner circle radius of the round about
DROP FUNCTION IF EXISTS check_inner_circle_ra(integer);
CREATE OR REPLACE FUNCTION check_inner_circle_ra(integer)
RETURNS real AS $$
  DECLARE
  	v_node_id ALIAS FOR $1;
	v_edge_id bigint;
	edge edge_ogd_aoi%ROWTYPE;
	middle geometry;
	dist_to_middle double precision;
	link_width double precision;
	innenkreis_radius double precision;
	
  BEGIN
  	SELECT INTO edge e.* FROM edge_ogd_aoi e 
	WHERE (e.nodefromid = v_edge_id OR e.nodefromid = v_edge_id) AND e.fow = 4;
	v_edge_id := edge.objectid;
  
  	WITH
		edge_geometry AS ( -- copy edge geom into variable
			SELECT ST_Transform(geom, 31256) as geom FROM edge_ogd_aoi 
			WHERE objectid = v_edge_id),
		 -- store three significant points in variables which are needed
		 -- to find out about the middle point
		points AS(
			SELECT ST_StartPoint(geom) as p1, 
			ST_LineInterpolatePoints(geom, 0.50, false) as p2, 
			ST_EndPoint(geom) as p3 
			FROM edge_geometry),
		radius AS ( -- get the distance between the points
			SELECT p1, p2, p3, (ST_Distance(p1, p2)*1.1) as circle_radius FROM points),
		 -- this number is now used to serve as the radius so circles can be drawn
		circles AS (
			SELECT (ST_ExteriorRing(ST_Buffer(p1, circle_radius))) as circle1,
					(ST_ExteriorRing(ST_Buffer(p2, circle_radius))) as circle2,
					(ST_ExteriorRing(ST_Buffer(p3, circle_radius))) as circle3
			FROM radius),
		-- get the intersection points of the circles and make them lines
  		intersection_points AS (
			SELECT ST_MakeLine(ST_Intersection(circle1, circle2)) as set1, 
			ST_MakeLine(ST_Intersection(circle2, circle3)) as set2
			FROM circles)
	
	 -- where these lines meet, there is the middle point of the round about
	SELECT INTO middle ST_Intersection(set1, set2) FROM intersection_points;
  
  	dist_to_middle := (ST_Distance(ST_Transform(ST_StartPoint(edge.geom), 31256), middle));
	SELECT INTO link_width l.width FROM edge_ogd_aoi e, gip_linknetz_ogd_aoi l 
	WHERE e.objectid = v_edge_id AND e.objectid = l.edge_id LIMIT 1;
	innenkreis_radius := dist_to_middle - (link_width/2);
	
	return innenkreis_radius;
  END;
$$ LANGUAGE 'plpgsql';




-- 6.2 - finds out, if one of the links that lead to the intersection belongs 
-- to a round about. the according attribute would be fow = 4
DROP FUNCTION IF EXISTS check_roundabout(integer);
CREATE OR REPLACE FUNCTION check_roundabout(integer) 
RETURNS boolean AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	ra boolean;
	no_ra_links integer;
 
  BEGIN
	-- get number of links that are part of a round about (formofway = 4)
  	no_ra_links := (SELECT COUNT(l.*) FROM gip_linknetz_ogd_aoi l 
					WHERE (l.from_node = node_id OR l.to_node = node_id) AND l.formofway = 4);
	
	IF (no_ra_links > 0) THEN
	 -- if one or more links with fow = 4 were found and counted in no_ra_links, 
	 -- the function returns true
		ra = TRUE;
	ELSE
		ra = FALSE; -- else, false is returned
	END IF;
	
	return ra; -- return whether the intersection belongs to a round about or not.

  END;
$$ LANGUAGE 'plpgsql';	



-- 6.3 - finds out, whether there is cycle infrastructure within the roundabout
DROP FUNCTION IF EXISTS check_cyclinfra_in_ra(integer);
CREATE OR REPLACE FUNCTION check_cyclinfra_in_ra(integer) 
RETURNS boolean AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	ci_exists boolean;
	no_edges integer;
	v_edge edge_ogd_aoi%ROWTYPE;
	no_lu integer;
	v_linearuse linearuse_ogd_aoi%ROWTYPE;
	counter_cycl_inf integer;
 
  BEGIN
  --going with edges as they also hold the necessary information 
  -- (the links also do), but are better connected to the linear uses
	no_edges := (SELECT COUNT(*) FROM edge_ogd_aoi e 
				 WHERE (e.nodefromid = node_id OR e.nodetoid = node_id)); 
	 -- first, the boolean saying whether cycling infrastructure is available, 
	 --  is set to zero
	ci_exists := FALSE;
	
	FOR q IN 1..no_edges LOOP
		-- this function is only called in case the intersections was classified as
		-- part of a roundabout before. 
		-- it is checked whether there is a separated linearuse for bicyclists - this 
		-- would mean that there is some kind of separated infrastructure for cyclists
		SELECT INTO v_edge e.* FROM edge_ogd_aoi e 
		WHERE (e.nodefromid = node_id OR e.nodetoid = node_id) 
		ORDER BY e.objectid LIMIT 1 OFFSET q-1;
		
		counter_cycl_inf := 0;
		
		IF v_edge.fow = 4 THEN
			 -- get number of linearuses connected to the current edge
			no_lu := (SELECT COUNT(*) FROM linearuse_ogd_aoi 
					  WHERE edge_id = v_edge.objectid 
					  AND basetype IN (2, 22, 23, 31, 33, 35, 36));
			counter_cycl_inf := counter_cycl_inf + 1;
			
			
			IF counter_cycl_inf > 0 THEN
				ci_exists := TRUE;
				return ci_exists;
			END IF;
		END IF;
		
	END LOOP;
	
	 -- return whether the intersection belongs to a round about or not.
	return ci_exists;

  END;
$$ LANGUAGE 'plpgsql';	



----------- CYCLING INFRASTRUCTURE ----------------------

-- 7.1 - is there mixed traffic - if yes, which kind?
DROP FUNCTION IF EXISTS check_mixed_traffic(bigint, bigint);
CREATE OR REPLACE FUNCTION check_mixed_traffic(bigint, bigint) 
RETURNS varchar(45) AS $$ 
  DECLARE
  	 -- from the linearuse, I need to get to the gip_linknetz. 
	 -- therefore, i have to go through edge
  	linearuse_lanes_fid ALIAS FOR $1;
	v_node_id ALIAS FOR $2;
	linearuse_id bigint;
	v_edge_id bigint;
	v_link_id bigint;
	v_use_id bigint;
	my_bikehike bikehike%ROWTYPE;
	bikefeature varchar(10);

  BEGIN
  
 	linearuse_id := (SELECT ll.lu_objectid FROM linearuse_lanes ll 
					 WHERE ll.fid = linearuse_lanes_fid);
	RAISE NOTICE 'LInearuse FID: %', linearuse_id;
	v_edge_id := (SELECT l.edge_id FROM linearuse_ogd_aoi l 
				  WHERE l.objectid = linearuse_id);
	RAISE NOTICE 'Edge ID: %', v_edge_id;
	v_link_id := (SELECT l.link_id FROM gip_linknetz_ogd_aoi l 
				  WHERE l.edge_id = v_edge_id LIMIT 1);
	RAISE NOTICE 'Link ID: %', v_link_id;
	
	-- get the use_id of the layer bikehike that is referring to the linear use
	 -- then get the linkuse's use_id. As there can be so many as 25 use_ids for 
	 -- one link, we have to check to get the one which belongs to the 
	 -- correct linearuse (found out via the offset to the link)
	v_use_id := (SELECT lku.use_id 
				 FROM linkuse_aoi lku 
				 WHERE lku.link_id = v_link_id 
				 	AND lku.offsett = (SELECT ROUND(offsetavg::decimal, 1)
									   FROM linearuse_ogd_aoi 
									   WHERE objectid = (SELECT ll.lu_objectid
														FROM linearuse_lanes ll
														WHERE ll.fid = linearuse_lanes_fid
														)
									  )
				);
	
	RAISE NOTICE 'Use ID: %', v_use_id;
 	
	SELECT INTO my_bikehike bh.* FROM bikehike bh WHERE bh.use_id = v_use_id;
	
	-- if the lane is not a car lane, it does not matter which side we look at - 
	-- because bike lanes are not split in my model
	IF ((SELECT basetype FROM linkuse_aoi WHERE use_id = v_use_id) <> 1) THEN 
		IF (my_bikehike.bikefeaturetow IS NOT NULL) THEN
			bikefeature := my_bikehike.bikefeaturetow;
		ELSIF (my_bikehike.bikefeaturebkw IS NOT NULL) THEN
			bikefeature := my_bikehike.bikefeaturebkw;
		ELSE
			bikefeature := NULL;
		END IF;
		
	-- in case of the lane being for cars, we need to have a look, if it is in 
	-- the same digitisation direction as the link or against the dig. direction. 
	-- This needs to be done because the values differ depending on the direction.
	ELSE 		
		IF ((SELECT to_node FROM gip_linknetz_ogd_aoi WHERE link_id = v_link_id) = 
			(SELECT leads_to FROM linearuse_lanes WHERE fid = linearuse_lanes_fid)) THEN 
			--get the linearuses which are directed in the same direction as the 
			-- link they are derived from
			bikefeature := my_bikehike.bikefeaturetow;
		ELSIF ((SELECT to_node FROM gip_linknetz_ogd_aoi WHERE link_id = v_link_id) = 
			   (SELECT comes_from FROM linearuse_lanes WHERE fid = linearuse_lanes_fid)) THEN 
			-- get the backwards attribute as link and linearuse_lane do not have
			-- the same direction
			bikefeature := my_bikehike.bikefeaturebkw;
		END IF;
		
	END IF;
	
	return bikefeature;
	
  END;
$$ LANGUAGE 'plpgsql';	


-- 7.2 - is there any cycling infrastructure? and what kind is it?
DROP FUNCTION IF EXISTS check_cycl_infra(bigint, bigint);
CREATE OR REPLACE FUNCTION check_cycl_infra(bigint, bigint) 
RETURNS varchar(40) AS $$ 
  DECLARE
  	v_linearuse_lane_fid ALIAS FOR $1;
	v_node_id ALIAS FOR $2;
	v_linearuse linearuse_lanes%ROWTYPE;
	v_cycl_infr varchar(100);
	v_linearuse_id bigint;
	v_edge_id bigint;
	v_link_id bigint;
	v_use_id bigint;
 
  BEGIN
  	v_cycl_infr := NULL;
	SELECT INTO v_linearuse ll.* FROM linearuse_lanes ll WHERE ll.fid = v_linearuse_lane_fid;
	RAISE NOTICE 'in check_cycl_infr. v_linearuse.fid = %', v_linearuse.fid;
	
	-- Option 1: check basetype
	--check whether the basetype of the linearuse already means, 
	-- that it is a bicycle infrastructure
	IF (v_linearuse.basetype IN (2, 22, 23, 31, 33, 35, 36)) THEN 
		v_cycl_infr := (SELECT lb.name FROM lut_basetype lb 
						WHERE lb.id = v_linearuse.basetype);
		return v_cycl_infr;
	END IF;
	
	-- Option 2: check Bikehike
	v_linearuse_id := (SELECT ll.lu_objectid FROM linearuse_lanes ll 
					   WHERE ll.fid = v_linearuse_lane_fid);
	v_edge_id := (SELECT l.edge_id FROM linearuse_ogd_aoi l 
				  WHERE l.objectid = v_linearuse_id);
	v_link_id := (SELECT l.link_id FROM gip_linknetz_ogd_aoi l 
				  WHERE l.edge_id = v_edge_id LIMIT 1);
	
		-- get the use_id of the layer bikehike that is referring to the linear use
		 -- then get the linkuse's use_id. As there can be so many as 25 use_ids for 
		 -- one link, we have to check to get the one which belongs to the correct 
		 -- linearuse (found out via the offset to the link)
	v_use_id := (SELECT lku.use_id 
				 FROM linkuse_aoi lku 
				 WHERE lku.link_id = v_link_id 
				 	AND lku.offsett = (SELECT ROUND(offsetavg::decimal, 1)
									   FROM linearuse_ogd_aoi 
									   WHERE objectid = (SELECT ll.lu_objectid
														FROM linearuse_lanes ll
														WHERE ll.fid = v_linearuse_lane_fid
														)
									  )
				);
	
	-- is the linearuse_lane directed inthe same direction as the link 
	-- -> is the lane tow?
	IF (v_linearuse.leads_to = (SELECT gl.to_node FROM gip_linknetz_ogd_aoi gl 
								WHERE gl.link_id = v_link_id)) THEN 
		v_cycl_infr := (SELECT bh.bikefeaturetow FROM bikehike bh WHERE bh.use_id = v_use_id);
	
	-- the lane is bkw compared to its parent link
	ELSIF (v_linearuse.comes_from = (SELECT gl.to_node FROM gip_linknetz_ogd_aoi gl 
									 WHERE gl.link_id = v_link_id)) THEN
		v_cycl_infr := (SELECT bh.bikefeaturebkw FROM bikehike bh WHERE bh.use_id = v_use_id);
	END IF;
	
	IF (v_cycl_infr IS NULL) THEN
	ELSE
		return v_cycl_infr;
	END IF;
	
	IF v_cycl_infr IS NULL THEN
		return NULL;
	END IF;
	
	
  END;
$$ LANGUAGE 'plpgsql';





----------- MORE GENERAL HELPER FUNCTIONS -----------------

--- read bit-mask
DROP FUNCTION IF EXISTS read_bitmask(integer, varchar(4));
CREATE OR REPLACE FUNCTION read_bitmask(integer, varchar(4)) 
RETURNS boolean[] AS $$ 
  DECLARE
  	linkid ALIAS FOR $1;
	variable ALIAS FOR $2;
	bit_len integer;
	v_access bit(7);
	accesses boolean [7]; 
	-- the rows are for the 7 access that are documented in the bit mask: 
	-- 0 - pedestrian, 1 - bike, 2 - private car, 3 - public bus, 4 - railway, 
	-- 5 - tram, 6 - subway, 7 - ferry boat. for more information see GIP Documentation
	-- helpful resource for handling bit strings: 
	-- https://www.postgresql.org/docs/current/functions-bitstring.html
 
  BEGIN
  	bit_len := 7;
  	
	CASE variable
		 -- variable gets filled with value from the link whose id was given (toward value)
		WHEN 'l_t'  THEN v_access := (SELECT access_tow FROM gip_linknetz_ogd_aoi WHERE linkid = link_id)::bit(7);
		-- variable gets filled with value from the link whose id was given (backward value)
		WHEN 'l_b'  THEN v_access := (SELECT access_bkw FROM gip_linknetz_ogd_aoi WHERE linkid = link_id)::bit(7); 
		-- table: bikehike, direction: towards
		WHEN 'bh_t' THEN v_access := (SELECT use_access_tow FROM bikehike WHERE linkdid = link_id)::bit(7); 
		 -- table: bikehike, direction: backwards
		WHEN 'bh_b' THEN v_access := (SELECT use_access_bkw FROM bikehike WHERE linkdid = link_id)::bit(7);
	END CASE;
	
	FOR q IN 1..bit_len LOOP
		-- go the the last value of the bit-mask (pedestrians). check if it is one (=1) 
		-- if yes: set accesses[0] = true, else: set accesses[0] = false
		IF get_bit(v_access, (bit_len - q)) = 1 THEN 
			accesses[q-1] := TRUE;
		ELSE
			accesses[q-1] := FALSE;
		END IF;
		
	END LOOP;
	
	RAISE NOTICE 'ACCESS ARRAY: %', accesses;
	 -- 1st value: Pedestrian, 2: Bike, 3: Private Car, 
	 -- 4: Public Bus, 5: Railway, 6: Tram, 7: Subway
	return accesses;

  END;
$$ LANGUAGE 'plpgsql';	




