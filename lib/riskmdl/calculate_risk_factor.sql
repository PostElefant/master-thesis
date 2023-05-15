DROP FUNCTION IF EXISTS weighting(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION weighting(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric)
RETURNS void AS $$ 
  DECLARE
  	weight_urban ALIAS FOR $1;
	weight_rails ALIAS FOR $2;
	weight_traffic_lights ALIAS FOR $3;
	weight_intersection_legs ALIAS FOR $4;
	weight_speed ALIAS FOR $5;
	weight_lane_number_cars ALIAS FOR $6;
	weight_lane_number_bikes ALIAS FOR $7;
	weight_gradient ALIAS FOR $8;
	weight_street_type ALIAS FOR $9;
	weight_round_about ALIAS FOR $10;
	weight_round_about_inner_circle ALIAS FOR $11;
	weight_round_about_cycle_infstr ALIAS FOR $12;
	weight_cycle_infrastructure ALIAS FOR $13;
	weight_mixed_traffic ALIAS FOR $14;
	
	no_lanes integer;
	nrv_lane normalized_risk_values%ROWTYPE;
	weight_counter numeric; -- in this variable, indicator*weight is summed up
	sum_weights numeric;
	v_risk_factor numeric;
	 
  BEGIN
  	no_lanes := (SELECT COUNT(*) FROM normalized_risk_values);
	
	DELETE FROM weighted_turnuses;
	
  	FOR q IN 1..no_lanes LOOP
		-- loop through each turning relation
		SELECT INTO nrv_lane nrv.* FROM normalized_risk_values nrv ORDER BY fid LIMIT 1 OFFSET (q-1);
		weight_counter := 0;
		sum_weights := 0.0;
		
		-- in each of these if-statements it is checked, whether information
		-- concerning the variable is available, and whether is is weighted.
		-- if so, the product of factor's weight * factor's normalized risk value 
		-- is added to the variable weight_counter.
		-- finally, the weight is added to the variable sum_weights
		
		-- urban
		IF (nrv_lane.urban IS NOT NULL AND weight_urban IS NOT NULL AND weight_urban > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.urban * weight_urban));
			sum_weights := sum_weights + weight_urban;
		END IF;
		
		-- rails
		-- Harris et al. (2013) detected that rails solely do play a role when the 
		-- intersection is not regulated by traffic lights
		IF (nrv_lane.rails IS NOT NULL AND weight_rails IS NOT NULL AND weight_rails > 0 
			AND (nrv_lane.traffic_lights IS NULL OR weight_traffic_lights IS NULL 
				 OR weight_traffic_lights <= 0)) THEN
			weight_counter := (weight_counter + (nrv_lane.rails * weight_rails));
			sum_weights := sum_weights + weight_rails;
		END IF;
		
		-- traffic lights
		IF (nrv_lane.traffic_lights IS NOT NULL AND weight_traffic_lights IS NOT NULL 
			AND weight_traffic_lights > 0) THEN
			weight_counter := (weight_counter 
							   + (nrv_lane.traffic_lights * weight_traffic_lights));
			sum_weights := sum_weights + weight_traffic_lights;
		END IF;
		
		-- edge degree
		IF (nrv_lane.intersection_legs IS NOT NULL AND weight_intersection_legs IS NOT NULL AND weight_intersection_legs > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.intersection_legs * weight_intersection_legs));
			sum_weights := sum_weights + weight_intersection_legs;
		END IF;
		
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
		
		-- road type
		IF (nrv_lane.street_type IS NOT NULL AND weight_street_type IS NOT NULL AND weight_street_type > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.street_type * weight_street_type));
			sum_weights := sum_weights + weight_street_type;
		END IF;
		
		-- roundabout inner circle
		IF (nrv_lane.round_about_inner_circle IS NOT NULL AND weight_round_about_inner_circle IS NOT NULL AND weight_round_about_inner_circle > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.round_about_inner_circle * weight_round_about_inner_circle));
			sum_weights := sum_weights + weight_round_about_inner_circle;
		END IF;
		
		-- roundabout present?
		IF (nrv_lane.round_about IS NOT NULL AND weight_round_about IS NOT NULL AND weight_round_about > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.round_about * weight_round_about));
			sum_weights := sum_weights + weight_round_about;
		END IF;
		
		-- roundabout cycle infrastructure
		IF (nrv_lane.round_about_cycle_infstr IS NOT NULL AND weight_round_about_cycle_infstr IS NOT NULL AND weight_round_about_cycle_infstr > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.round_about_cycle_infstr * weight_round_about_cycle_infstr));
			sum_weights := sum_weights + weight_round_about_cycle_infstr;
		END IF;
		
		-- mixed traffic
		IF (nrv_lane.mixed_traffic IS NOT NULL AND weight_mixed_traffic IS NOT NULL AND weight_mixed_traffic > 0) THEN
			weight_counter := (weight_counter + (nrv_lane.mixed_traffic * weight_mixed_traffic));
			sum_weights := sum_weights + weight_mixed_traffic;
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
		
		-- the risk factor of a turning relation is calculated by dividing the sum of 
		-- the weighted normalized factors by the sum of the weights
		v_risk_factor := (weight_counter / sum_weights);
		
		INSERT INTO weighted_turnuses (fid, geom, risk_factor)
		VALUES (nrv_lane.fid, (SELECT ST_Transform(i.curved_geom, 3857) 
							   FROM iplateau i WHERE i.fid = nrv_lane.fid), v_risk_factor);

	
	END LOOP;
  

	
  END;
$$ LANGUAGE 'plpgsql';	
