DROP FUNCTION IF EXISTS get_risk_factors(integer);
CREATE OR REPLACE FUNCTION get_risk_factors(integer) 
RETURNS void AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	no_turnuses integer;
	no_edges integer;
	v_edge_id bigint;
	turnuse_id integer;
	v_traffic_lights boolean;
	v_intersection_legs integer;
	v_speed integer;
	v_round_about boolean; 
	v_urban boolean;
	v_rails boolean;
	v_gradient real;
	v_no_car_lanes integer;
	v_no_bike_lanes integer;
	v_cyclinfra_in_ra boolean;
	v_road_type boolean;
	v_inner_circle_ra double precision;
	v_mixed_traffic_f varchar(10);
	v_mixed_traffic_t varchar(10);
	v_cycle_infrastructure_f varchar(45);
	v_cycle_infrastructure_t varchar(45);
	 
  BEGIN
  
---- 0 - DELETE OLD VALUES FROM TABLE
  	-- table in which all the values are stored that are obtained in this function
	DELETE FROM risk_value_table;
	
	-- fill fid, turnuse_objectid and basetype with the values of the table iplateau
	no_turnuses := (SELECT COUNT(*) FROM iplateau);
	FOR q IN 1..no_turnuses LOOP
		INSERT INTO risk_value_table (fid, turnuse_objectid, basetype)
		VALUES (
			(SELECT fid FROM iplateau ORDER BY fid LIMIT 1 OFFSET q-1),
			(SELECT turnuse_objectid FROM iplateau ORDER BY fid LIMIT 1 OFFSET q-1),
			(SELECT basetype FROM iplateau ORDER BY fid LIMIT 1 OFFSET q-1)
		);
	END LOOP;
	
	UPDATE risk_value_table SET nodeid = node_id;
	
	
------ 1 - SURROUNDING INFRASTRUCTURE
	-- 1.1 - urban | checks whether one of the links which are leading to the intersection is declared urban in the GIP
	-- Notice: in the area of interest, all of the links are urban
	v_urban := check_urban(node_id);
	UPDATE risk_value_table SET urban = v_urban;
	RAISE NOTICE 'Urban?: %', v_urban;
	
	-- 1.2 - trains | checks whether there are any rails in the radius of the intersection
	v_rails := check_rails(node_id);
	UPDATE risk_value_table SET rails = v_rails;
	RAISE NOTICE 'Rails?: %', v_rails;
	
------ 2 - TRAFFIC RULES
	-- 2.1 - traffic lights | compares the node id that is given with a table which contains all traffic lights in the AOI. I've inserted the intersection's id that the traffic light belongs to in the table. So what is done is simply checking whether the node id can be found in the TL table.
	v_traffic_lights := check_traffic_lights(node_id);
	UPDATE risk_value_table SET traffic_lights = v_traffic_lights;
	RAISE NOTICE 'Traffic Lights?: %', v_traffic_lights;
	
	
------ 3 - INTERSECTION GEOMETRY
	-- 3.1 - number of legs of an intersection
	v_intersection_legs := (SELECT edgedegree FROM node_ogd_aoi n WHERE n.objectid = node_id);
	UPDATE risk_value_table SET intersection_legs = v_intersection_legs;
	RAISE NOTICE 'Edge degree: %', v_intersection_legs;
	
------ 4 - BEHAVIOR
	v_speed := get_speed(node_id);
	UPDATE risk_value_table SET speed = v_speed;
	RAISE NOTICE 'Highest speed: %', v_speed;


------ 5 - STREET CHARACTERISTICS
	-- 5.1 - number of lanes: implemented in the local factors segment
	-- 5.2 - gradient, slope implemented in teh local factors segment.
	-- 5.3 - physical barriers:
	-- 5.4 - road types:
	-- 5.4: Road Type
	v_road_type := check_streettypes(v_edge_id); -- get info of minor/major road
	UPDATE risk_value_table SET street_type = v_road_type;

------ 6 - ROUNDABOUT
	-- 6.1 - the radius of the inner circle - is in the if-clause below.
	-- 6.2 - is it a roundabout?
	v_round_about := check_roundabout(node_id);
	UPDATE risk_value_table SET round_about = v_round_about;
	RAISE NOTICE 'Roundabout?: %', v_round_about;
	
	
	IF v_round_about IS TRUE THEN -- the function is only called if one of the parts of the intersection belongs to a roundabout.
		-- 6.1 - the radius of the inner circle
		v_inner_circle_ra := check_inner_circle_ra(node_id);
		UPDATE risk_value_table SET round_about_inner_circle = v_inner_circle_ra;
		-- 6.3 - is there cycling infrastructure in the roundabout?
		v_cyclinfra_in_ra := check_cyclinfra_in_ra(node_id);
		UPDATE risk_value_table SET round_about_cycle_infstr = v_cyclinfra_in_ra;
	END IF;
	
	
------ 7 - CYCLING INFRASTRUCTURE
	-- 7.1 mixed traffic - is called in get local factors
	-- 7.2 cycling infrastructure - is called in get local factors

------ GET THE LOCAL FACTORS --------------------------------
	-- get the number of edges
	no_edges := (SELECT COUNT(*) FROM (SELECT COUNT(e.*) FROM iplateau i, linearuse_ogd_aoi l, linearuse_lanes ll, edge_ogd_aoi e 
 				 WHERE i.linearuse_start_id = ll.fid
				 	AND ll.lu_objectid = l.objectid
 					AND l.edge_id = e.objectid
 				 GROUP BY e.objectid) as no_of_linuses_belonging_to_edge);
	
	-- loop through edges and get edge-related factors 
	FOR q IN 1..no_edges LOOP
		v_edge_id := (SELECT e.objectid FROM edge_ogd_aoi e WHERE e.nodefromid = node_id OR e.nodetoid = node_id ORDER BY e.objectid LIMIT 1 OFFSET q-1);
		
		-- 5.2: Gradient
		v_gradient := check_gradient_slope(v_edge_id); -- get gradient of edge
		
		UPDATE risk_value_table SET gradient = v_gradient
		FROM iplateau, linearuse_lanes, linearuse_ogd_aoi
			WHERE risk_value_table.turnuse_objectid = iplateau.turnuse_objectid 
			AND iplateau.linearuse_start_id = linearuse_lanes.fid 
			AND linearuse_lanes.lu_objectid = linearuse_ogd_aoi.objectid
			AND linearuse_ogd_aoi.edge_id = v_edge_id;				
		
	END LOOP; --end loop through edges
	
	
	-- loop throught turnuses and get turnuse-related factors
	FOR q IN 1..no_turnuses LOOP
		turnuse_id := (SELECT fid FROM iplateau ORDER BY fid LIMIT 1 OFFSET q-1);
		
		-- 5.1.1: Number of crossed car lanes
		v_no_car_lanes := car_lanes_crossed(turnuse_id);
		UPDATE risk_value_table SET lane_number_cars = v_no_car_lanes WHERE fid = turnuse_id;
		
		-- 5.1.2: Number of crossed pathways and cycle infrastructure
		v_no_bike_lanes := bike_lanes_crossed(turnuse_id);
		UPDATE risk_value_table SET lane_number_bikes = v_no_bike_lanes WHERE fid = turnuse_id;
		
		-- 7.1 mixed traffic: get it for the linearuse before and the linearuse after the turnuse
		v_mixed_traffic_f := check_mixed_traffic((SELECT linearuse_start_id FROM iplateau WHERE fid = turnuse_id), node_id); -- before turnuse
		UPDATE risk_value_table SET mixed_traffic_f = v_mixed_traffic_f WHERE fid = turnuse_id;
		v_mixed_traffic_t := check_mixed_traffic((SELECT linearuse_end_id FROM iplateau WHERE fid = turnuse_id), node_id);
		UPDATE risk_value_table SET mixed_traffic_t = v_mixed_traffic_t WHERE fid = turnuse_id;
		
		-- 7.2 cycling infrastructure: get it for the linearuse before and the linearuse after the turnuse
		v_cycle_infrastructure_f := check_cycl_infra(turnuse_id, (SELECT linearuse_start_id FROM iplateau WHERE fid = turnuse_id), node_id); -- before turnuse
		UPDATE risk_value_table SET cycle_infrastructure_f = v_cycle_infrastructure_f WHERE fid = turnuse_id;
		v_cycle_infrastructure_t := check_cycl_infra(turnuse_id, (SELECT linearuse_end_id FROM iplateau WHERE fid = turnuse_id), node_id); -- after turnuse
		UPDATE risk_value_table SET cycle_infrastructure_t = v_cycle_infrastructure_t WHERE fid = turnuse_id;
		
	END LOOP; --end loop through turnuses
	
  END;
$$ LANGUAGE 'plpgsql';	