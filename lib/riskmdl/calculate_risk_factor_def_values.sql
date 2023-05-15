-- this function uses the default values for the weighting  process
-- therefore, no user inputs are required

DROP FUNCTION IF EXISTS weighting_def();
CREATE OR REPLACE FUNCTION weighting_def()
RETURNS void AS $$ 
  DECLARE
	weight_speed numeric;
	weight_lane_number_cars numeric;
	weight_lane_number_bikes numeric;
	weight_gradient numeric;
	weight_round_about numeric;
	weight_cycle_infrastructure numeric;
	
	no_lanes integer;
	nrv_lane normalized_risk_values%ROWTYPE;
	weight_counter numeric; -- in this variable, indicator*weight is summed up
	sum_weights numeric;
	v_risk_factor numeric;
	 
  BEGIN
  	no_lanes := (SELECT COUNT(*) FROM normalized_risk_values);
	
	DELETE FROM weighted_turnuses;
	
	weight_speed := 0.3;
	weight_lane_number_cars := 0.15;
	weight_lane_number_bikes := 0.05;
	weight_gradient := 0.1;
	weight_round_about := 0.2;
	weight_cycle_infrastructure := 0.2;
	
  	FOR q IN 1..no_lanes LOOP
		-- loop through each turning relation
		SELECT INTO nrv_lane nrv.* FROM normalized_risk_values nrv ORDER BY fid LIMIT 1 OFFSET (q-1);
		weight_counter := 0;
		sum_weights := 0.0;
		
		-- speed
		IF (nrv_lane.speed IS NOT NULL AND weight_speed IS NOT NULL AND weight_speed > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.speed * weight_speed));
			sum_weights := sum_weights + weight_speed;
		END IF;
		
		-- number of crossed turning relations (cars)
		IF (nrv_lane.lane_number_cars IS NOT NULL AND weight_lane_number_cars IS NOT NULL AND weight_lane_number_cars > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.lane_number_cars * weight_lane_number_cars));
			sum_weights := sum_weights + weight_lane_number_cars;
		END IF;
		
		-- number of crossed turning relations (VRUs)
		IF (nrv_lane.lane_number_bikes IS NOT NULL AND weight_lane_number_bikes IS NOT NULL AND weight_lane_number_bikes > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.lane_number_bikes * weight_lane_number_bikes));
			sum_weights := sum_weights + weight_lane_number_bikes;
		END IF;
		
		-- gradient
		IF (nrv_lane.gradient IS NOT NULL AND weight_gradient IS NOT NULL AND weight_gradient > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.gradient * weight_gradient));
			sum_weights := sum_weights + weight_gradient;
		END IF;
		
		-- roundabout 
		IF (nrv_lane.round_about IS NOT NULL AND weight_round_about IS NOT NULL AND weight_round_about > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.round_about * weight_round_about));
			sum_weights := sum_weights + weight_round_about;
		END IF;
		
		-- cycling infrastructure
		IF (nrv_lane.cycle_infrastructure IS NOT NULL AND weight_cycle_infrastructure IS NOT NULL AND weight_cycle_infrastructure > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.cycle_infrastructure * weight_cycle_infrastructure));
			sum_weights := sum_weights + weight_cycle_infrastructure;
		END IF;
		
		

		
		RAISE NOTICE 'Fid: %', nrv_lane.fid;
		RAISE NOTICE 'Weight Counter: %', weight_counter;
		RAISE NOTICE 'Sum of weights: %', sum_weights;	
		RAISE NOTICE '_______________________________________________________________';
		
		v_risk_factor := (weight_counter / sum_weights);
		
		INSERT INTO weighted_turnuses (fid, geom, risk_factor)
		VALUES (nrv_lane.fid, (SELECT ST_Transform(i.curved_geom, 3857) FROM iplateau i 
							   WHERE i.fid = nrv_lane.fid), v_risk_factor);

	
	END LOOP;
  

	
  END;
$$ LANGUAGE 'plpgsql';	

