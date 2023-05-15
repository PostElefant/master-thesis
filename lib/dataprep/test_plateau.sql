-- this function builds the 1D and 2D version of the intersection node
-- it builds upon the 1D results of the lane construction script
-- the outputs of this function serve as the base of the risk model

SET search_path = 's1078788', 'public';
DROP FUNCTION IF EXISTS build_plateau(integer);
CREATE OR REPLACE FUNCTION build_plateau(integer) 
RETURNS void AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	no_turnuses_side INTEGER;
  	turnuse turnuse_ogd_aoi%ROWTYPE;
	turnuse_car help_turnuses_cars%ROWTYPE;
	--table that holds the turnuse options of the intersection for cars
	var_available_turnuses available_turnuses%ROWTYPE; 
	node node_ogd_aoi%ROWTYPE;
	turnuse_id bigint;
	lane_start linearuse_lanes%ROWTYPE;
	lane_end linearuse_lanes%ROWTYPE;	
	lane_start2 linearuse_lanes%ROWTYPE;
	lane_end2 linearuse_lanes%ROWTYPE;
	turnuse_start_point geometry;
	turnuse_end_point geometry;
	turnuse_start_point2 geometry;
	turnuse_end_point2 geometry;	
	start_twidth double precision; -- width the turnuse buffer has at its start
	end_twidth double precision; -- width the turnuse buffer has at its end
	lane_at_tustart boolean; --boolean that is true, if the start lane is at the startpoint of the turnuse. the bool is false if the endpoint is the startpoint of the turnuse
	turnuse_buff_geom geometry;  
	turnuse_basetype integer;
	no_turnuses_car integer;
	no_available_turnuses integer;
	turnuse_car_point1 geometry;
	turnuse_car_point2 geometry;
	intermediate_point geometry;
	elongated_l_geom geometry;
	elongated_ll_geom geometry;
	intersection_point_elongated_lls geometry;
	record_hc record;
	no_actual_carlanes integer;
	linearuse_lane_car linearuse_lanes%ROWTYPE;
	ll_start_fid bigint;
	ll_end_fid bigint;

  
  BEGIN
  
  	-- get number of turnuses in the intersection that are for pedestrians/cyclists 
  	no_turnuses_side := (SELECT COUNT(t.*) FROM turnuse_ogd_aoi t 
						 WHERE t.via_node_id = node_id 
						 	AND basetype IN (2, 7, 21, 22, 23, 33, 35, 36, 37, 41));
	RAISE NOTICE 'no_turnuses_side: %', no_turnuses_side;
	
	SELECT INTO node n.* FROM node_ogd_aoi n WHERE n.objectid=node_id;
	
	 -- the if-clause stretches over the whole script. 
	 -- it just reassures that no error is thrown because there simply are..
	 -- ..no turnuses when the node is at the end of a one-way-street
	IF (node.edgedegree > 1) THEN
	
	--formerly, the iplateau was created here. this was moved into the setup-script
	DELETE FROM iplateau;
	
-------

-- loop through the turnuses of pedestrians and cyclists
FOR q in 1..no_turnuses_side LOOP
	
	SELECT INTO turnuse t.* FROM turnuse_ogd_aoi t 
	-- Basetypes for bicycle infrastructure: 2, 22, 23, 31, 33, 35, 36 
	-- Basetypes for pedestrians: 7, 21, 37, 41
	WHERE t.via_node_id = node_id 
		AND basetype IN (2, 7, 21, 22, 23, 31, 33, 35, 36, 37, 41)
	ORDER BY t.objectid 
	LIMIT 1
	OFFSET (q-1);
	
	turnuse_id := turnuse.objectid;
	turnuse_basetype := turnuse.basetype;	
		
 IF (turnuse.basetype IN (2, 7, 21, 22, 23, 31, 33, 35, 36, 41)) THEN 
 	lane_start := NULL;
	lane_end := NULL;
	turnuse_start_point := NULL;
	turnuse_end_point := NULL;
	
	-- store linearuse_lane that connects to the turnuse in variable
	SELECT INTO lane_start l.* 
	FROM linearuse_lanes l, turnuse_ogd_aoi t 
	WHERE t.use_from_id=l.lu_objectid AND t.objectid=turnuse_id;
	
	-- store 2nd linearuse_lane connected to turnuse in 2nd variable
	SELECT INTO lane_end l.* 
	FROM linearuse_lanes l, turnuse_ogd_aoi t 
	WHERE t.use_to_id=l.lu_objectid AND t.objectid=turnuse_id;
	
	-- store the start point of the turnuse geometry in a variable
	turnuse_start_point := ST_Transform(ST_StartPoint(turnuse.geom),31259); 
	-- store the end point of the turnuse geometry in a variable
	turnuse_end_point := ST_Transform(ST_EndPoint(turnuse.geom),31259); 
	
	
-- there exist bike turnuses that connect a bike line with a car lane. 
-- the problem is: the car lane most likely is not anymore at the place it used to be
-- this is because with the lane building in teh previous step, it was moved,
-- and also most likely it was duplicated. 
-- so the turnuse connecting bike and car lane needs to be recalculated.
-- this is done in the following part of the code
------- getting into the  if-clause that connects bike with car lanes (if needed)
	
	IF(((lane_start.basetype=1 AND lane_end.basetype<>1) 
		OR (lane_start.basetype<>1 AND lane_end.basetype=1)) IS TRUE) THEN
		
		no_actual_carlanes := (SELECT COUNT(ll.*) FROM linearuse_lanes ll 
							   WHERE ll.lu_objectid = lane_start.lu_objectid);
		
		FOR k in 1..no_actual_carlanes LOOP
	
			--getting the bikelanes that merge into car lanes
			--change their start- or endpoints so that they go..
			-- ..into the car lanes - not in the middle of them
			IF((lane_start.basetype=1 AND lane_end.basetype<>1) IS TRUE) THEN
			
				-- Generally: the tupels of the table linearuse_lanes are being...
				-- ...handled individually into the variable lane_start2. (it is...
				-- ...just a transfer of the data from one variable to another...
				-- ...to prevent the variables from being set incorrectly)
				SELECT INTO lane_start2 l.* FROM linearuse_lanes l
				WHERE l.lu_objectid = lane_start.lu_objectid 
				ORDER BY l.fid asc LIMIT 1 OFFSET (k-1); 
			   	
				RAISE NOTICE 'car lane towards cycle lane';
			   	RAISE NOTICE '(Car) edge now corresponds to % lanes', 
					(SELECT COUNT(e.*) FROM linearuse_lanes e 
					 WHERE e.lu_objectid = lane_start.lu_objectid);
				
				-- this if-block is simply for discovering the connections of the turnuse. 
				-- to which linearuses is it connected? at which linearuse does it start, ..
				-- ..at which does it end? (especially important for car lanes)
				IF (lane_start2.leads_to = node_id) THEN -- does lane_start2 (of which we know that it's a car lane) lead to the intersection and is therefore the beginning of the turnuse?
					ll_start_fid := lane_start2.fid;
					ll_end_fid := lane_end.fid;
					
					-- I know that in lane_start the car lane is stored. I also know that if we..
					-- ..are in this if-statement, the lane leads towards the node we are inter-
					-- ested in. Therefore, the start of the turnuse is the end of the carlane
					turnuse_start_point2 := (SELECT ST_EndPoint(ll.lu_geom) FROM linearuse_lanes ll 
											 WHERE ll.fid = ll_start_fid);
					
					-- in lane_end, the bike lane is stored.
					-- we are not interested in the direction of the bike lane, nor are we sure..
					-- ..whether it's directed correctly. Hence, we still use ST_Closest_Point
					turnuse_end_point2 := (SELECT ST_ClosestPoint(ll.lu_geom, 
																  (SELECT ST_Transform(n.geom, 31259) 
																   FROM node_ogd_aoi n 
																   WHERE n.objectid = node_id)) 
										   FROM linearuse_lanes ll WHERE ll.fid = ll_end_fid); 
				
				
				-- turn the whole procedure around as in this version, the car lane (lane_start)..
				-- .. is coming from the node. Therefore it is the starting point of the turnuse
				ELSE
					ll_start_fid := lane_end.fid;
					ll_end_fid := lane_start2.fid;
					
					turnuse_start_point2 := (SELECT ST_ClosestPoint(ll.lu_geom, 
																	(SELECT ST_Transform(n.geom, 31259) 
																	 FROM node_ogd_aoi n 
																	 WHERE n.objectid = node_id)
																   ) 
											 FROM linearuse_lanes ll 
											 WHERE ll.fid = ll_start_fid);
					
					turnuse_end_point2 := (SELECT ST_StartPoint(ll.lu_geom) 
										   FROM linearuse_lanes ll 
										   WHERE ll.fid = ll_end_fid);
				END IF;
			
			-- if the car lane is stored in lane_end and the bicycle lane is lane_start
			ELSIF((lane_start.basetype<>1 AND lane_end.basetype=1) IS TRUE) THEN
				SELECT INTO lane_end2 l.* FROM linearuse_lanes l 
				WHERE l.lu_objectid = lane_end.lu_objectid ORDER BY l.fid LIMIT 1 OFFSET (k-1);
				
			   	RAISE NOTICE 'Bicycle lane towards car lane';
			   	RAISE NOTICE 'Edge corresponds now to % lanes', 
					(SELECT COUNT(e.*) FROM linearuse_lanes e 
					 WHERE e.lu_objectid = lane_end.lu_objectid);
			   
				-- this if-block is simply for discovering the connections of the turnuse.
				-- is the linearuse lane_end2 (of which we know that it's a car lane), ..
				-- ..the linearuse leading to the intersection?
			   	IF (lane_end2.leads_to = node_id) THEN 
			   		ll_start_fid := lane_end2.fid; -- car lane is start of turnuse
					ll_end_fid := lane_start.fid; -- bike lane is end of turnuse
					
					-- the car lane is stored in lane_end. 
					-- in this if-part, the car lane is the lane, the turnuse starts from
					turnuse_start_point2 := (SELECT ST_EndPoint(ll.lu_geom) 
											 FROM linearuse_lanes ll WHERE ll.fid = ll_start_fid);
					turnuse_end_point2 := (SELECT ST_ClosestPoint(ll.lu_geom, 
																  (SELECT ST_Transform(n.geom, 31259) 
																   FROM node_ogd_aoi n 
																   WHERE n.objectid = node_id)) 
										   FROM linearuse_lanes ll WHERE ll.fid = ll_end_fid);
				
				ELSE -- the other way around: the turnuse ends in the car lane
					ll_start_fid := lane_start.fid; -- bike lane is start of turnuse
					ll_end_fid := lane_end2.fid; -- car lane is end of car lane
					
					turnuse_start_point2 := (SELECT ST_ClosestPoint(ll.lu_geom, 
																	(SELECT ST_Transform(n.geom, 31259) 
																	 FROM node_ogd_aoi n WHERE n.objectid = node_id)) 
											 FROM linearuse_lanes ll WHERE ll.fid = ll_start_fid);
					turnuse_end_point2 := (SELECT ST_StartPoint(ll.lu_geom) 
										   FROM linearuse_lanes ll WHERE ll.fid = ll_end_fid);
				END IF;
			   
			END IF;
			
			elongated_l_geom := NULL;
			elongated_ll_geom := NULL;
			
			----------------------------------------------------------------------------------
			-- finding out about the widths at the two different ends of the turnuse geometry
			IF(ST_Distance(ST_Transform(turnuse_start_point2,31259), 
						   ST_Transform(ST_StartPoint(lane_start2.lu_geom),31259))<0.1) THEN 
				start_twidth := lane_start.width;
				lane_at_tustart := TRUE;			
				RAISE NOTICE 'Startpoint und lane_start';

			
			ELSIF(ST_Distance(ST_Transform(turnuse_start_point2,31259), 
							  ST_Transform(ST_EndPoint(lane_start2.lu_geom),31259))<0.1) THEN
				start_twidth := lane_start.width;
				lane_at_tustart := TRUE;
				RAISE NOTICE 'Endpoint und lane_start';

				
			ELSIF(ST_Distance(ST_Transform(turnuse_start_point2,31259), 
							  ST_Transform(ST_StartPoint(lane_end2.lu_geom),31259))<0.1) THEN
				start_twidth := lane_end.width;
				lane_at_tustart := FALSE;		
				RAISE NOTICE 'Startpoint und lane_end';

				
			ELSIF(ST_Distance(ST_Transform(turnuse_start_point2,31259), 
							  ST_Transform(ST_EndPoint(lane_end2.lu_geom),31259))<0.1) THEN
				start_twidth := lane_end.width;
				lane_at_tustart := FALSE;
				RAISE NOTICE 'Endpoint und lane_end';

				
			ELSE RAISE NOTICE 'I do not know what is happening here - help connect';
			END IF;

			
			---------------------------------------------------------------------------
			
			
			-- depending on which end of the turnuse could not be attributed with the width, now gets it
			IF (lane_at_tustart = TRUE) THEN
				end_twidth := lane_end.width;
			ELSIF (lane_at_tustart = FALSE) THEN
				end_twidth := lane_start.width;
			ELSE
				RAISE EXCEPTION 'Width of lanes could not be connected to turnuse.';
			END IF;
						
		
			--calculating the apex point by calling the function get_intermediate_point()		
			intermediate_point := NULL;
			SELECT INTO intermediate_point get_intermediate_point(
				ST_MakeLine(turnuse_start_point2, turnuse_end_point2), 
				node_id);
			
 
			--building the turnuse buffer by using a convex hull
				turnuse_buff_geom := ST_ConvexHull( ST_Collect( ST_Collect(
    			    ST_Buffer(turnuse_start_point2, start_twidth/2),
					ST_Buffer(intermediate_point, (start_twidth + end_twidth)/4)),
    			    ST_Buffer(turnuse_end_point2, end_twidth/2)
    			));
			
			RAISE NOTICE 'TS2: %, Intermed. Pt.: %, TE2: %, Curve: %', 
				ST_AsText(turnuse_start_point2), ST_AsText(intermediate_point), 
				ST_AsText(turnuse_end_point2), ST_CurveToLine(
					CreateCurve(ST_MakeLine(turnuse_start_point2, 
											ST_MakeLine(intermediate_point, turnuse_end_point2)
										   )
							   ));
							   
			--storing the results in table
			INSERT INTO iplateau(turnuse_objectid, turnuse_geom, turnuse_buff_geom, 
								 start_point_geom, end_point_geom, linearuse_start_id, 
								 linearuse_end_id, start_width, end_width, basetype, 
								 curved_geom, intermediate_point, el_geom1, el_geom2)
			VALUES (turnuse_id, ST_Transform(ST_MakeLine(turnuse_start_point2, 
														 turnuse_end_point2),31259), 
					turnuse_buff_geom, turnuse_start_point2, turnuse_end_point2, ll_start_fid, 
					ll_end_fid, start_twidth, end_twidth, turnuse_basetype, 
					ST_CurveToLine(CreateCurve(ST_MakeLine(
						turnuse_start_point2, ST_MakeLine(intermediate_point, turnuse_end_point2)))),
					intersection_point_elongated_lls, elongated_l_geom, elongated_ll_geom);   
			
		END LOOP;

----------------------the "normal" bike turnuses -------------------------------

	ELSE --meaning every turnuse that is between two normal bike lanes (no car lane involved)
	
	elongated_l_geom := NULL;
	elongated_ll_geom := NULL;
	
	--CALLING THE FUNCTION HELP_CONNECT
	RAISE NOTICE 'lanestart width: %, laneend width: %, lanestart geom: %, 
	laneend geom: %, tu start geom: %, tu end geom: %', 
	lane_start.width, lane_end.width, ST_AsText(lane_start.lu_geom), 
	ST_AsText(lane_end.lu_geom), ST_AsText(turnuse_start_point), 
	ST_AsText(turnuse_end_point);
	
	record_hc := help_connect(lane_start.width, lane_end.width, lane_start.lu_geom,
							  lane_end.lu_geom, turnuse_start_point, turnuse_end_point);
	
	--storing the results in variables
	start_twidth := record_hc.start_twidth;
	lane_at_tustart := record_hc.lane_at_tustart;
	--elongated_l_geom  := record_hc.elongated_l_geom;
	--elongated_ll_geom  := record_hc.elongated_ll_geom;
	
	
	--depending on which end of the turnuse could 
	--not be attributed with the width, now gets it
	IF (lane_at_tustart = TRUE) THEN
		end_twidth := lane_end.width;
	ELSIF (lane_at_tustart = FALSE) THEN
		end_twidth := lane_start.width;
	ELSE
		RAISE EXCEPTION 'Width of lanes could not be connected to turnuse.';
	END IF;
	
	-- store the linearuses, the turnuse borders to, in variables
	ll_start_fid := lane_start.fid; -- it is not determined, if in "lane_start" really the start of the lane is stored. Because we are dealing with bike lanes, it just might not matter as the cyclists might drive in both directions
	ll_end_fid := lane_end.fid;
	
	-- calculate the apex point of the curved turnuse
	intermediate_point := NULL;
	SELECT INTO intermediate_point get_intermediate_point(ST_MakeLine(
		turnuse_start_point, turnuse_end_point), node_id);
	

	-- building convex hull around the buffered start-, apex-, and endpoint
	turnuse_buff_geom := ST_ConvexHull( ST_Collect( ST_Collect(
        ST_Buffer(turnuse_start_point, start_twidth/2),
		ST_Buffer(intermediate_point, (start_twidth + end_twidth)/4)),
        ST_Buffer(turnuse_end_point, end_twidth/2)
    ));
	
	
	--storing the results in table
	INSERT INTO iplateau(turnuse_objectid, turnuse_geom, turnuse_buff_geom,
						 start_point_geom, end_point_geom, start_width, end_width, basetype, 
						 curved_geom, intermediate_point, el_geom1, el_geom2, 
						 linearuse_start_id, linearuse_end_id)
	VALUES (turnuse_id, ST_Transform(turnuse.geom,31259), turnuse_buff_geom, 
			turnuse_start_point, turnuse_end_point, start_twidth, end_twidth, turnuse_basetype,
			ST_CurveToLine(CreateCurve(ST_MakeLine(turnuse_start_point, ST_MakeLine(
				intermediate_point, turnuse_end_point)))), 
			intersection_point_elongated_lls, elongated_l_geom, elongated_ll_geom, 
			ll_start_fid, ll_end_fid);
    
  	END IF; --ending if-else for the bike-car-lane problem
  END IF; --ending if-else that checks whether the turnuse.basetype = 2, 7, ...
 END LOOP; --ending the loop that goes through all the existing turnuses with the basetypes = 2, 7, ...
 
 
 
 
  ------------------------------- ONLY CARS ----------------------------------
  
  
	--creating a table by generating all the possible combinations of the 
	-- linearuses (for cars)- so the table holds all the possible turnuses
	DROP TABLE IF EXISTS help_turnuses_cars CASCADE;
	CREATE  TABLE help_turnuses_cars AS
		SELECT DISTINCT l.fid as l_fid, ll.fid as ll_fid, l.lu_objectid as l_lu_objectid,
		ll.lu_objectid as ll_lu_objectid, l.lu_geom as l_lu_geom, 
		ll.lu_geom as ll_lu_geom, l.width as l_width, ll.width as ll_width, 
		l.basetype as basetype, l.leads_to as l_leads_to, l.comes_from as l_comes_from, 
		ll.leads_to as ll_leads_to, ll.comes_from as ll_comes_from, n.objectid as node_id 		
		FROM linearuse_lanes l, linearuse_lanes ll, node_ogd_aoi n
		WHERE l.basetype=1 AND ll.basetype=1
			AND l.lu_objectid <> ll.lu_objectid
			AND l.fid < ll.fid -- this way opposite duplicates get caught. 2-9 and 9-2 would be the same for me
			AND n.objectid = node_id;
	
	--how many possible combinations are there?
	no_turnuses_car := (SELECT COUNT(*) FROM help_turnuses_cars); 

	-- create table that holds all the turning relations that are avalable in GIP data
	DROP TABLE IF EXISTS available_turnuses CASCADE;
	CREATE TABLE available_turnuses AS 
		SELECT t.* FROM turnuse_ogd_aoi t WHERE t.via_node_id=node_id 
		AND t.basetype=1; --is used for determining all the turnuse options that are "available" for cars
	
	-- get number of availabe turning relations
	no_available_turnuses := (SELECT COUNT(*) FROM available_turnuses);
	 
	 --looping through all the possible turnuses
	 FOR p IN 1.. no_turnuses_car LOOP
		
		--transferring always in each loop one tuple of the possible turnuses
		turnuse_car:=NULL;
		SELECT INTO turnuse_car htc.* FROM help_turnuses_cars htc 
		ORDER BY l_fid, ll_fid
		LIMIT 1
		OFFSET (p-1);
		
	 
	 --the following if-clause makes sure that the turnuses do not connect lanes 
	 -- with each other that have different driving directions
	 IF(turnuse_car.l_leads_to <> turnuse_car.ll_leads_to 
		AND turnuse_car.l_comes_from <> turnuse_car.ll_comes_from) THEN
	
		-------------------------------------------------------------------------
		
		IF (turnuse_car.l_leads_to = node_id)  THEN
			turnuse_car_point1 := ST_EndPoint(turnuse_car.l_lu_geom);
			--creating the elongated version of the first segment of the linearuse curve in order to determine on which side the curvature of the turnuse needs to be
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_StartPoint(turnuse_car.l_lu_geom),31259), ST_Transform(ST_PointN(turnuse_car.l_lu_geom,2),31259));
		ELSE
			turnuse_car_point2 := ST_StartPoint(turnuse_car.l_lu_geom);
			--creating the elongated version of the last segment of the linearuse (for intermediate point)
			elongated_l_geom := elongate_linearuse(ST_Transform(ST_EndPoint(turnuse_car.l_lu_geom),31259), ST_Transform(ST_PointN(turnuse_car.l_lu_geom,-2),31259));
		END IF;
		

		IF (turnuse_car.ll_leads_to = node_id) THEN
			turnuse_car_point1 := ST_EndPoint(turnuse_car.ll_lu_geom);
			--RAISE NOTICE 'Loop %; Es wurde ll.start mit einer Distanz von %', p, ST_Distance(ST_Transform(node.geom,31259), ST_Transform(ST_StartPoint(turnuse_car.ll_lu_geom),31259));
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_StartPoint(turnuse_car.ll_lu_geom),31259), ST_Transform(ST_PointN(turnuse_car.ll_lu_geom,2),31259));
		ELSE
			turnuse_car_point2 := ST_StartPoint(turnuse_car.ll_lu_geom);
			--RAISE NOTICE 'Loop %; Es wurde ll.end mit einer Distanz von %', p, ST_Distance(ST_Transform(node.geom,31259), ST_Transform(ST_EndPoint(turnuse_car.ll_lu_geom),31259));
			elongated_ll_geom := elongate_linearuse(ST_Transform(ST_EndPoint(turnuse_car.ll_lu_geom),31259), ST_Transform(ST_PointN(turnuse_car.ll_lu_geom,-2),31259));
		END IF;
		
		-------------------------------------------------------------------------
		-- i want the turnuse to hold the FIDs of the linearuse_lanes which it connects
		-- we know where it starts and ends because we have l_comes_from, l_leads_to and
		-- the node_id. the geometries of the linear uses are assigned accordingly.
		-- by re-connecting the ids, it is possible to get the fid
		-- Note: it is an unfortunate coincidence that both variable begin with "ll". 
		-- they are not connected in any other way than explained above.
		IF (turnuse_car.l_leads_to = node_id) THEN -- if linearuse 1 leads to the node, it is also the start point of the turnuse...
			ll_start_fid := turnuse_car.l_fid;
			ll_end_fid := turnuse_car.ll_fid; -- ... and the start point of linearuse 2 is the end point of the turnuse
		ELSIF (turnuse_car.ll_leads_to = node_id) THEN
			ll_start_fid := turnuse_car.ll_fid;
			ll_end_fid := turnuse_car.l_fid;
		ELSE 
			ll_start_fid := 0;
			ll_end_fid := 0;
		END IF;
				
		
		--construct the start- and end point of each buffer in order 
		-- to build a convex hull around them in the end
		turnuse_start_point := NULL;
		turnuse_end_point := NULL;
		
		turnuse_start_point := ST_Transform(turnuse_car_point1, 31259);
		turnuse_end_point := ST_Transform(turnuse_car_point2, 31259);
	
		
		--check whether the constructed turnuse also exists in the data
		FOR o IN 1..no_available_turnuses LOOP
		
			SELECT INTO var_available_turnuses at.* FROM available_turnuses at
				ORDER BY fid
				LIMIT 1
				OFFSET (o-1);
				
			IF ((turnuse_car.l_lu_objectid = var_available_turnuses.use_from_id 
				 AND turnuse_car.ll_lu_objectid = var_available_turnuses.use_to_id)
					OR(turnuse_car.l_lu_objectid = var_available_turnuses.use_to_id 
					   AND turnuse_car.ll_lu_objectid = var_available_turnuses.use_from_id)) THEN
				
				
				--calculate the intersection point of the elongated linearuses... it will be needed to get the intermediate point
				RAISE NOTICE 'Startpoint: %, Endpoint: %', turnuse_car_point1, turnuse_car_point2;
				intersection_point_elongated_lls := NULL;
				RAISE NOTICE 'elongate1: %, elongate2: %', ST_AsText(elongated_l_geom),ST_AsText(elongated_ll_geom); 
				intersection_point_elongated_lls := ST_Intersection(ST_Transform(elongated_l_geom,31259), ST_Transform(elongated_ll_geom,31259));
				--get intermediate point of the constructed turnuse in order to round off the edges
				intermediate_point := NULL;
				--calling the function get_intermediate_point and store its result in the 
				-- variable intermediate_point
				SELECT INTO intermediate_point get_intermediate_point(ST_Transform(
					ST_MakeLine(turnuse_car_point1, turnuse_car_point2),31259), node_id);

				-- build the 2D geometry with the help of buffers and convex hulls
				turnuse_buff_geom := ST_ConvexHull( ST_Collect( ST_Collect(
    			    ST_Buffer(turnuse_start_point, turnuse_car.l_width/2),
					ST_Buffer(intermediate_point, (turnuse_car.l_width+turnuse_car.ll_width)/4)),
    			    ST_Buffer(turnuse_end_point, turnuse_car.ll_width/2)
    			));
				
				-- store result in the table iplateau
				-- the 1D versions (straight and curved turning relations) 
				-- are created in this insert-statement on the fly
				INSERT INTO iplateau(turnuse_geom, start_point_geom, end_point_geom, 
									 start_width, end_width, basetype, turnuse_buff_geom, 
									 curved_geom, intermediate_point, el_geom1, el_geom2, 
									 linearuse_start_id, linearuse_end_id)
				VALUES (ST_Transform(ST_MakeLine(turnuse_car_point1, turnuse_car_point2),31259), 
						turnuse_car_point1, turnuse_car_point2, turnuse_car.l_width, 
						turnuse_car.ll_width, 1, turnuse_buff_geom, 
						ST_CurveToLine(CreateCurve(ST_MakeLine(turnuse_start_point, ST_MakeLine(
							intermediate_point, turnuse_end_point)))), intermediate_point, 
						elongated_l_geom, elongated_ll_geom,ll_start_fid, ll_end_fid);
			END IF;
		END LOOP;
		
  	 END IF;
  	END LOOP;

  	
  
  	-- the turnuses belonging to the car lanes (basetype = 1) need to be assigned 
	-- the objectid of the original turnuses they belong to.
	-- this has to be done separately because those turnuses are not directly 
	-- derived from the original turnuse.
	-- however, this information is needed in the risk analysis.
	UPDATE iplateau 
	SET turnuse_objectid = (SELECT t.objectid 
							FROM turnuse_ogd_aoi t, linearuse_lanes ll, linearuse_lanes ll2, 
							linearuse_ogd_aoi l, linearuse_ogd_aoi l2
					   		WHERE linearuse_start_id = ll.fid AND linearuse_end_id = ll2.fid
					   	  		AND ll.lu_objectid = l.objectid AND ll2.lu_objectid = l2.objectid
					   	  		AND ((l.objectid = t.use_to_id AND l2.objectid = t.use_from_id) 
									OR (l.objectid = t.use_from_id AND l2.objectid = t.use_to_id)))
	WHERE iplateau.basetype = 1 
		AND iplateau.turnuse_objectid IS NULL;
  
 
 
	END IF; -- if clause that asks whether the edgedegree is > 1.
	
  END;
$$ LANGUAGE 'plpgsql';


