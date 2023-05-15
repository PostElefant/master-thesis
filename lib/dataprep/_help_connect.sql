--this function does the following:
--assigns the (lane)width to the startpoint of the turnuse
--finds out, which lane(linearuse) is at the startpoint of the turnuse

DROP FUNCTION IF EXISTS help_connect(double precision, double precision, 
									 geometry, geometry, geometry, geometry);
CREATE OR REPLACE FUNCTION help_connect(double precision, double precision, 
										geometry, geometry, geometry, geometry)
RETURNS record AS $$ 
  DECLARE
  	lane_start_width ALIAS FOR $1;
	lane_end_width ALIAS FOR $2;
	lane_start_lugeom ALIAS FOR $3;
	lane_end_lugeom ALIAS FOR $4;
	turnuse_start_point ALIAS FOR $5;
	turnuse_end_point ALIAS FOR $6;
	start_twidth double precision;
	lane_at_tustart boolean;
	elongated_l_geom geometry;
	elongated_ll_geom geometry;
	rec record;
	
BEGIN

	
	IF(ST_Distance(ST_Transform(turnuse_start_point,31259), ST_Transform(ST_StartPoint(lane_start_lugeom),31259))<0.1) THEN 
		start_twidth := lane_start_width;
		lane_at_tustart := TRUE;
		--the whole elongated stuff is to find out where the linearuses would meet. this is used to determine in which direction the turnuse needs to curve
		elongated_l_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,2),31259));
		IF(ST_Distance(ST_Transform(turnuse_end_point,31259), ST_Transform(ST_StartPoint(lane_end_lugeom),31259))<0.1) THEN
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,2),31259));
		ELSE
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,-2),31259));
		END IF;	
		RAISE NOTICE 'Startpoint und lane_start';
		SELECT start_twidth, lane_at_tustart, elongated_l_geom, elongated_ll_geom INTO rec;
		RETURN rec;
	
	ELSIF(ST_Distance(ST_Transform(turnuse_start_point,31259), ST_Transform(ST_EndPoint(lane_start_lugeom),31259))<0.1) THEN
		start_twidth := lane_start_width;
		lane_at_tustart := TRUE;
		elongated_l_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,-2),31259));
		IF(ST_Distance(ST_Transform(turnuse_end_point,31259), ST_Transform(ST_StartPoint(lane_end_lugeom),31259))<0.1) THEN
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,2),31259));
		ELSE 
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,-2),31259));
		END IF;	
		RAISE NOTICE 'Endpoint und lane_start';
		SELECT start_twidth, lane_at_tustart, elongated_l_geom, elongated_ll_geom INTO rec;
		RETURN rec;
		
	ELSIF(ST_Distance(ST_Transform(turnuse_start_point,31259), ST_Transform(ST_StartPoint(lane_end_lugeom),31259))<0.1) THEN
		start_twidth := lane_end_width;
		lane_at_tustart := FALSE;
		elongated_ll_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,2),31259));
		IF(ST_Distance(ST_Transform(turnuse_end_point,31259), ST_Transform(ST_StartPoint(lane_start_lugeom),31259))<0.1) THEN
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,-2),31259));
		ELSE
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,2),31259));
		END IF;			
		RAISE NOTICE 'Startpoint und lane_end';
		SELECT start_twidth, lane_at_tustart, elongated_l_geom, elongated_ll_geom INTO rec;
		RETURN rec;
		
	ELSIF(ST_Distance(ST_Transform(turnuse_start_point,31259), ST_Transform(ST_EndPoint(lane_end_lugeom),31259))<0.1) THEN
		start_twidth := lane_end_width;
		lane_at_tustart := FALSE;
		elongated_ll_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_end_lugeom),31259), ST_Transform(ST_PointN(lane_end_lugeom,-2),31259));
		IF(ST_Distance(ST_Transform(turnuse_start_point,31259), ST_Transform(ST_EndPoint(lane_end_lugeom),31259))<0.1) THEN
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_StartPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,2),31259));
		ELSE
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_EndPoint(lane_start_lugeom),31259), ST_Transform(ST_PointN(lane_start_lugeom,-2),31259));	
		END IF;
		RAISE NOTICE 'Endpoint und lane_end';
		SELECT start_twidth, lane_at_tustart, elongated_l_geom, elongated_ll_geom INTO rec;
		RETURN rec;
		
	ELSE 
		RAISE NOTICE 'help, whats happening?';
		RAISE NOTICE 'Values are assumed now to prevent errors!';
		
		start_twidth := lane_end_width;
		lane_at_tustart := FALSE;
		SELECT start_twidth, lane_at_tustart, NULL, NULL INTO rec;
		RETURN rec;
		
	END IF;
  
 
  
END;
$$ LANGUAGE 'plpgsql';