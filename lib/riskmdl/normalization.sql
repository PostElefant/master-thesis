DROP FUNCTION IF EXISTS normalize_factors();
CREATE FUNCTION normalize_factors()
RETURNS void AS $$
DECLARE
	no_lanes integer;
	current_lane risk_value_table%ROWTYPE;
	v_fid integer;
	v_indicator numeric;
	v_indicator_help numeric;

BEGIN
	no_lanes := (SELECT COUNT(*) FROM risk_value_table);
	
	DELETE FROM normalized_risk_values;

	
	FOR q IN 1..no_lanes LOOP
	
		SELECT INTO  current_lane rvt.* FROM risk_value_table rvt 
		ORDER BY fid LIMIT 1 OFFSET (q-1);
		
		v_fid := current_lane.fid;
		
		INSERT INTO normalized_risk_values (fid, nodeid) 
		VALUES (v_fid, current_lane.nodeid);
		
		
		------------INDICATORS-----------------------------------
		-- 0 -> unbikeable
		-- 1 -> very bikeable
		
		-- 1.1 urban
		 v_indicator :=
		 	CASE
				WHEN current_lane.urban = TRUE THEN 1.0
				WHEN current_lane.urban = FALSE THEN 0.0
				WHEN current_lane.urban IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET urban = v_indicator WHERE fid = v_fid;
		
		-- 1.2 rails
		 v_indicator :=
		 	CASE
				WHEN current_lane.rails = TRUE THEN 0.0
				WHEN current_lane.rails = FALSE THEN 1
				WHEN current_lane.rails IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET rails = v_indicator WHERE fid = v_fid;
		
		-- 2.1 traffic_lights
		v_indicator :=
		 	CASE
				WHEN current_lane.traffic_lights = TRUE THEN 0
				WHEN current_lane.traffic_lights = FALSE THEN 1
				WHEN current_lane.traffic_lights IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET traffic_lights = v_indicator WHERE fid = v_fid;
		
		-- 3.1 intersection_legs
		v_indicator :=
		 	CASE
				WHEN current_lane.intersection_legs <= 2 THEN 1
				WHEN current_lane.intersection_legs = 3 THEN 0.7
				WHEN current_lane.intersection_legs = 4 THEN 0.5
				WHEN current_lane.intersection_legs = 5 THEN 0.1
				WHEN current_lane.intersection_legs >= 6 THEN 0.0
				WHEN current_lane.intersection_legs IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET intersection_legs = v_indicator WHERE fid = v_fid;
		
		-- 4.1 speed
		v_indicator :=
		 	CASE
				WHEN current_lane.speed >= 100 THEN 0
				WHEN current_lane.speed >= 80 THEN 0.2
				WHEN current_lane.speed >= 70 THEN 0.3
				WHEN current_lane.speed >= 60 THEN 0.4
				WHEN current_lane.speed >= 50 THEN 0.6
				WHEN current_lane.speed >= 30 THEN 0.85
				WHEN current_lane.speed > 0 THEN 0.9
				WHEN current_lane.speed = 0 THEN 1
				WHEN current_lane.speed IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET speed = v_indicator WHERE fid = v_fid;
		
		-- 5.1 number of lanes that are being crossed
		 -- cars
		v_indicator :=
		 	CASE
				WHEN current_lane.lane_number_cars >= 7 THEN 0
				WHEN current_lane.lane_number_cars = 6 THEN 0.05
				WHEN current_lane.lane_number_cars = 5 THEN 0.1
				WHEN current_lane.lane_number_cars = 4 THEN 0.25
				WHEN current_lane.lane_number_cars = 3 THEN 0.3
				WHEN current_lane.lane_number_cars = 2 THEN 0.5
				WHEN current_lane.lane_number_cars = 1 THEN 0.6
				WHEN current_lane.lane_number_cars = 0 THEN 1
				WHEN current_lane.lane_number_cars IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET lane_number_cars = v_indicator WHERE fid = v_fid;
		 -- bikes
		v_indicator :=
		 	CASE
				WHEN current_lane.lane_number_bikes >= 10 THEN 0
				WHEN current_lane.lane_number_bikes BETWEEN 7 AND 9 THEN 0.25
				WHEN current_lane.lane_number_bikes BETWEEN 4 AND 6 THEN 0.5
				WHEN current_lane.lane_number_bikes BETWEEN 1 AND 3 THEN 0.75
				WHEN current_lane.lane_number_bikes <= 0 THEN 1
				WHEN current_lane.lane_number_bikes IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET lane_number_bikes = v_indicator WHERE fid = v_fid;
		
		-- 5.2 gradient
		v_indicator :=
		 	CASE
				WHEN current_lane.gradient >= 0.2 THEN 0
				WHEN current_lane.gradient >= 0.1 THEN 0.15
				WHEN current_lane.gradient >= 0.07 THEN 0.2
				WHEN current_lane.gradient >= 0.05 THEN 0.3
				WHEN current_lane.gradient >= 0.03 THEN 0.55
				WHEN current_lane.gradient >= 0.01 THEN 0.8
				WHEN current_lane.gradient < 0.01 THEN 1
				WHEN current_lane.gradient IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET gradient = v_indicator WHERE fid = v_fid;
		
		-- 5.3 physical barriers
		
		-- 5.4 Street types
		v_indicator :=
		 	CASE
				WHEN current_lane.street_type = TRUE  THEN 0.0-- major road
				WHEN current_lane.street_type = FALSE  THEN 1.0 -- minor road
				WHEN current_lane.street_type IS NULL   THEN NULL
			END;
		UPDATE normalized_risk_values SET street_type = v_indicator WHERE fid = v_fid;
		
		-- 6.1 inner circle of round about
		v_indicator :=
		 	CASE
				WHEN current_lane.round_about_inner_circle >= 20 THEN 0
				WHEN current_lane.round_about_inner_circle <= 20 THEN 0.2
				WHEN current_lane.round_about_inner_circle <= 15 THEN 0.4
				WHEN current_lane.round_about_inner_circle <= 10 THEN 0.6
				WHEN current_lane.round_about_inner_circle <= 7 THEN 0.8
				WHEN current_lane.round_about_inner_circle <= 3 THEN 1
				WHEN current_lane.round_about_inner_circle IS NULL   THEN NULL
			END;
		UPDATE normalized_risk_values SET round_about_inner_circle = v_indicator WHERE fid = v_fid;
		
		-- 6.2 existence round about
		 v_indicator :=
		 	CASE
				WHEN current_lane.round_about = TRUE THEN 0.0
				WHEN current_lane.round_about = FALSE THEN 1.0
				WHEN current_lane.round_about IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET round_about = v_indicator WHERE fid = v_fid;
		
		-- 6.3 cycling lane in round about
		v_indicator :=
		 	CASE
				WHEN current_lane.round_about_cycle_infstr = TRUE THEN 1.0
				WHEN current_lane.round_about_cycle_infstr = FALSE THEN 0.0
				WHEN current_lane.round_about_cycle_infstr IS NULL THEN NULL
			END;
		UPDATE normalized_risk_values SET round_about_cycle_infstr = v_indicator WHERE fid = v_fid;
		
		
		
		-- 7.1 mixed traffic
		-- the from-lanes
		v_indicator :=
		 	CASE
				WHEN current_lane.mixed_traffic_f LIKE 'TRF' THEN  0.0 -- Trasse nur fuer Fussgaenger
				WHEN current_lane.mixed_traffic_f LIKE 'MZSTR' THEN  0.0 -- Mehrzweckstreifen
				WHEN current_lane.mixed_traffic_f LIKE 'BGZ'  THEN 0.1 -- Begegnungszone
				WHEN current_lane.mixed_traffic_f LIKE 'RFUE' THEN 0.1 -- Radfahrerueberfahrt
				WHEN current_lane.mixed_traffic_f LIKE 'WSTR' THEN 0.25-- Radfahren in Wohnstrassen
				WHEN current_lane.mixed_traffic_f LIKE 'BS'  THEN 0.25 -- Radfahren auf Busspuren
				WHEN current_lane.mixed_traffic_f LIKE 'GRW_M' THEN 0.3 -- Gemischter Geh- und Radweg
				WHEN current_lane.mixed_traffic_f LIKE 'FUZO' THEN 0.3 -- Radfahren in Fussgaengerzonen
				WHEN current_lane.mixed_traffic_f LIKE 'GRW_MO' THEN 0.35 -- Gemischter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.mixed_traffic_f LIKE 'ABBK'  THEN 0.4 -- Anrainerstr. Radverkehr
				WHEN current_lane.mixed_traffic_f LIKE 'RFGE' THEN  0.4 -- Radfahren gegen die Einbahn
				WHEN current_lane.mixed_traffic_f LIKE 'RFGE_N' THEN  0.45 -- Radfahren gegen die Einbahn (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_f LIKE 'RWO' THEN  0.55 -- Radweg ohne Benuetzungspflicht
				WHEN current_lane.mixed_traffic_f LIKE 'RR' THEN  0.55 -- Radroute (beschilderte Route, Radverkehr wird im Mischverkehr gefuehrt)
				WHEN current_lane.mixed_traffic_f LIKE 'RVW' THEN  0.6 -- Radfahren auf verkehrsarmen Wegen
				WHEN current_lane.mixed_traffic_f LIKE 'VK_BE' THEN  0.7 -- Verkehrsberuhigte Bereiche
				WHEN current_lane.mixed_traffic_f LIKE 'FUZO_N' THEN 0.75 -- Radfahren in Fussgaengerzonen (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_f LIKE 'GRW_TO' THEN  0.75 -- Getrennter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.mixed_traffic_f LIKE 'RW' THEN  0.8 -- Baulicher Radweg
				WHEN current_lane.mixed_traffic_f LIKE 'GRW_T' THEN  0.8 -- Getrennter Geh- und Radweg
				WHEN current_lane.mixed_traffic_f LIKE 'TRR' THEN  0.8 -- Treppe auch fuer Radfahrer geeignet
				WHEN current_lane.mixed_traffic_f LIKE 'RF' THEN  0.85 -- Radfahrstreifen
				WHEN current_lane.mixed_traffic_f LIKE 'WSTR_N' THEN  0.85 -- Radfahren in Wohnstrassen (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_f LIKE 'RRN' THEN  0.9 -- Hauptradroute
				WHEN current_lane.mixed_traffic_f LIKE 'FRS'  THEN 1 -- Fahrradstrasse
				
				WHEN (current_lane.basetype = 1 AND current_lane.mixed_traffic_f IS NULL) THEN 0.0 -- car lane without bicycle infrastructure
				WHEN (current_lane.basetype IN (7, 21, 37, 41) AND current_lane.mixed_traffic_f IS NULL) THEN 0.15 -- pedestrian lane without bicycle infrastructure
				
				WHEN current_lane.mixed_traffic_f LIKE 'MTB' THEN NULL -- Mountainbikestrecke (im Wald). Null da es sich nicht auf mein Thema bezieht und auch nicht auf meine AOI.
				WHEN current_lane.mixed_traffic_f LIKE 'SGT' THEN NULL -- Singletrail - keine Ahnung.
				WHEN current_lane.mixed_traffic_f LIKE 'FE' THEN NULL -- Faehre
				WHEN current_lane.mixed_traffic_f LIKE 'HI_IV' THEN NULL
				WHEN current_lane.mixed_traffic_f LIKE '-1'  THEN NULL
				WHEN current_lane.mixed_traffic_f IS NULL THEN NULL
			END;
		
		-- the to-lanes
		v_indicator_help :=
		 	CASE
				WHEN current_lane.mixed_traffic_t LIKE 'TRF' THEN  0.0 -- Trasse nur fuer Fussgaenger
				WHEN current_lane.mixed_traffic_t LIKE 'MZSTR' THEN  0.0 -- Mehrzweckstreifen
				WHEN current_lane.mixed_traffic_t LIKE 'BGZ'  THEN 0.1 -- Begegnungszone
				WHEN current_lane.mixed_traffic_t LIKE 'RFUE' THEN 0.1 -- Radfahrerueberfahrt
				WHEN current_lane.mixed_traffic_t LIKE 'WSTR' THEN 0.25-- Radfahren in Wohnstrassen
				WHEN current_lane.mixed_traffic_t LIKE 'BS'  THEN 0.25 -- Radfahren auf Busspuren
				WHEN current_lane.mixed_traffic_t LIKE 'GRW_M' THEN 0.3 -- Gemischter Geh- und Radweg
				WHEN current_lane.mixed_traffic_t LIKE 'FUZO' THEN 0.3 -- Radfahren in Fussgaengerzonen
				WHEN current_lane.mixed_traffic_t LIKE 'GRW_MO' THEN 0.35 -- Gemischter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.mixed_traffic_t LIKE 'ABBK'  THEN 0.4 -- Anrainerstr. Radverkehr
				WHEN current_lane.mixed_traffic_t LIKE 'RFGE' THEN  0.4 -- Radfahren gegen die Einbahn
				WHEN current_lane.mixed_traffic_t LIKE 'RFGE_N' THEN  0.45 -- Radfahren gegen die Einbahn (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_t LIKE 'RWO' THEN  0.55 -- Radweg ohne Benuetzungspflicht
				WHEN current_lane.mixed_traffic_t LIKE 'RR' THEN  0.55 -- Radroute (beschilderte Route, Radverkehr wird im Mischverkehr gefuehrt)
				WHEN current_lane.mixed_traffic_t LIKE 'RVW' THEN  0.6 -- Radfahren auf verkehrsarmen Wegen
				WHEN current_lane.mixed_traffic_t LIKE 'VK_BE' THEN  0.7 -- Verkehrsberuhigte Bereiche
				WHEN current_lane.mixed_traffic_t LIKE 'FUZO_N' THEN 0.75 -- Radfahren in Fussgaengerzonen (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_t LIKE 'GRW_TO' THEN  0.75 -- Getrennter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.mixed_traffic_t LIKE 'RW' THEN  0.8 -- Baulicher Radweg
				WHEN current_lane.mixed_traffic_t LIKE 'GRW_T' THEN  0.8 -- Getrennter Geh- und Radweg
				WHEN current_lane.mixed_traffic_t LIKE 'TRR' THEN  0.8 -- Treppe auch fuer Radfahrer geeignet
				WHEN current_lane.mixed_traffic_t LIKE 'RF' THEN  0.85 -- Radfahrstreifen
				WHEN current_lane.mixed_traffic_t LIKE 'WSTR_N' THEN  0.85 -- Radfahren in Wohnstrassen (Nebenfahrbahn)
				WHEN current_lane.mixed_traffic_t LIKE 'RRN' THEN  0.9 -- Hauptradroute
				WHEN current_lane.mixed_traffic_t LIKE 'FRS'  THEN 1 -- Fahrradstrasse
				
				WHEN (current_lane.basetype = 1 AND current_lane.mixed_traffic_t IS NULL) THEN 0.0 -- car lane without bicycle infrastructure
				WHEN (current_lane.basetype IN (7, 21, 37, 41) AND current_lane.mixed_traffic_t IS NULL) THEN 0.15 -- pedestrian lane without bicycle infrastructure
				
				WHEN current_lane.mixed_traffic_t LIKE 'MTB' THEN NULL -- Mountainbikestrecke (im Wald). Null da es sich nicht auf mein Thema bezieht und auch nicht auf meine AOI.
				WHEN current_lane.mixed_traffic_t LIKE 'SGT' THEN NULL -- Singletrail - keine Ahnung.
				WHEN current_lane.mixed_traffic_t LIKE 'FE' THEN NULL -- Faehre
				WHEN current_lane.mixed_traffic_t LIKE 'HI_IV' THEN NULL
				WHEN current_lane.mixed_traffic_t LIKE '-1'  THEN NULL
				WHEN current_lane.mixed_traffic_t IS NULL THEN NULL
			END;
		-- store the worse value (compare from-lane and to-lane) in the normalized table. Reason: The two will meet each other anyway, so the worse option is going to happen anyways.	
		IF (v_indicator <= v_indicator_help AND v_indicator IS NOT NULL) THEN
			UPDATE normalized_risk_values SET mixed_traffic = v_indicator WHERE fid = v_fid;
		ELSE
			UPDATE normalized_risk_values SET mixed_traffic = v_indicator_help WHERE fid = v_fid;
		END IF;		

		

		-- 7.2 cycling infrastructure. gleiche Dtenquelle wie oben, sollte aber anders gewertet weden
		-- the from-lane (the lane the turnuse comes from)
		v_indicator :=
		 	CASE
				-- option 1 & 2: basetype is cycling infrastructure
				WHEN current_lane.cycle_infrastructure_f LIKE 'Radfahrerueberfahrt' THEN 0.5
				WHEN current_lane.cycle_infrastructure_f LIKE 'Schutzweg und Radfahrerueberfahrt' THEN 0.5
				WHEN current_lane.cycle_infrastructure_f LIKE 'Radfahrstreifen' THEN 0.6
				WHEN current_lane.cycle_infrastructure_f LIKE 'Radfahrstreifen gegen die Einbahn' THEN 0.6
				WHEN current_lane.cycle_infrastructure_f LIKE 'Geh- und Radweg' THEN 0.65
				WHEN current_lane.cycle_infrastructure_f LIKE 'Radweg mit angrenzendem Gehweg' THEN 0.95
				WHEN current_lane.cycle_infrastructure_f LIKE 'Radweg' THEN 1
				-- option 3: look it up in bikehike
				WHEN current_lane.cycle_infrastructure_f LIKE 'BGZ'  THEN 0.0 -- Begegnungszone
				WHEN current_lane.cycle_infrastructure_f LIKE 'TRF' THEN  0.0 -- Trasse nur fuer Fussgaenger
				WHEN current_lane.cycle_infrastructure_f LIKE 'RFGE' THEN  0.1 -- Radfahren gegen die Einbahn
				WHEN current_lane.cycle_infrastructure_f LIKE 'ABBK'  THEN 0.1 -- Anrainerstr. Radverkehr
				WHEN current_lane.cycle_infrastructure_f LIKE 'FUZO' THEN 0.2 -- Radfahren in Fussgaengerzonen
				WHEN current_lane.cycle_infrastructure_f LIKE 'MZSTR' THEN  0.2 -- Mehrzweckstreifen
				WHEN current_lane.cycle_infrastructure_f LIKE 'RVW' THEN  0.3 -- Radfahren auf verkehrsarmen Wegen
				WHEN current_lane.cycle_infrastructure_f LIKE 'WSTR' THEN 0.3-- Radfahren in Wohnstrassen
				WHEN current_lane.cycle_infrastructure_f LIKE 'RFGE_N' THEN  0.4 -- Radfahren gegen die Einbahn (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_f LIKE 'TRR' THEN  0.4 -- Treppe auch fuer Radfahrer geeignet
				WHEN current_lane.cycle_infrastructure_f LIKE 'VK_BE' THEN  0.4 -- Verkehrsberuhigte Bereiche
				WHEN current_lane.cycle_infrastructure_f LIKE 'RR' THEN  0.45 -- Radroute (beschilderte Route, Radverkehr wird im Mischverkehr gefuehrt)
				WHEN current_lane.cycle_infrastructure_f LIKE 'GRW_MO' THEN 0.45 -- Gemischter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.cycle_infrastructure_f LIKE 'FUZO_N' THEN 0.5 -- Radfahren in Fussgaengerzonen (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_f LIKE 'GRW_M' THEN 0.5 -- Gemischter Geh- und Radweg
				WHEN current_lane.cycle_infrastructure_f LIKE 'BS'  THEN 0.6 -- Radfahren auf Busspuren
				WHEN current_lane.cycle_infrastructure_f LIKE 'RFUE' THEN 0.7 -- Radfahrerueberfahrt -- weil keine Ahnung...
				WHEN current_lane.cycle_infrastructure_f LIKE 'WSTR_N' THEN  0.7 -- Radfahren in Wohnstrassen (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_f LIKE 'RWO' THEN  0.8 -- Radweg ohne Benuetzungspflicht
				WHEN current_lane.cycle_infrastructure_f LIKE 'SGT' THEN 0.9 -- Singletrail 
				WHEN current_lane.cycle_infrastructure_f LIKE 'GRW_TO' THEN  0.9 -- Getrennter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.cycle_infrastructure_f LIKE 'GRW_T' THEN  1 -- Getrennter Geh- und Radweg
				WHEN current_lane.cycle_infrastructure_f LIKE 'RRN' THEN  1 -- Hauptradroute
				WHEN current_lane.cycle_infrastructure_f LIKE 'RW' THEN  1 -- Baulicher Radweg
				WHEN current_lane.cycle_infrastructure_f LIKE 'RF' THEN  1 -- Radfahrstreifen
				WHEN current_lane.cycle_infrastructure_f LIKE 'MTB' THEN 1 -- Mountainbikestrecke (im Wald). 
				WHEN current_lane.cycle_infrastructure_f LIKE 'FRS'  THEN 1 -- Fahrradstrasse
				WHEN current_lane.cycle_infrastructure_f LIKE 'FE' THEN NULL
				WHEN current_lane.cycle_infrastructure_f LIKE 'HI_IV' THEN NULL
				WHEN current_lane.cycle_infrastructure_f LIKE '-1'  THEN 0
				WHEN current_lane.cycle_infrastructure_f IS NULL THEN 0
			END;
		
		-- the to-lane (the lane the turnuse leads to)
		v_indicator_help :=
		 	CASE
				-- option 1: basetype is cycling infrastructure
				WHEN current_lane.cycle_infrastructure_t LIKE 'Radfahrerueberfahrt' THEN 0.5
				WHEN current_lane.cycle_infrastructure_t LIKE 'Schutzweg und Radfahrerueberfahrt' THEN 0.5
				WHEN current_lane.cycle_infrastructure_t LIKE 'Radfahrstreifen' THEN 0.6
				WHEN current_lane.cycle_infrastructure_t LIKE 'Radfahrstreifen gegen die Einbahn' THEN 0.6
				WHEN current_lane.cycle_infrastructure_t LIKE 'Geh- und Radweg' THEN 0.65
				WHEN current_lane.cycle_infrastructure_t LIKE 'Radweg mit angrenzendem Gehweg' THEN 0.95
				WHEN current_lane.cycle_infrastructure_t LIKE 'Radweg' THEN 1
				-- option 2: look it up in bikehike
				WHEN current_lane.cycle_infrastructure_t LIKE 'BGZ'  THEN 0.0 -- Begegnungszone
				WHEN current_lane.cycle_infrastructure_t LIKE 'TRF' THEN  0.0 -- Trasse nur fuer Fussgaenger
				WHEN current_lane.cycle_infrastructure_t LIKE 'RFGE' THEN  0.1 -- Radfahren gegen die Einbahn
				WHEN current_lane.cycle_infrastructure_t LIKE 'ABBK'  THEN 0.1 -- Anrainerstr. Radverkehr
				WHEN current_lane.cycle_infrastructure_t LIKE 'FUZO' THEN 0.2 -- Radfahren in Fussgaengerzonen
				WHEN current_lane.cycle_infrastructure_t LIKE 'MZSTR' THEN  0.2 -- Mehrzweckstreifen
				WHEN current_lane.cycle_infrastructure_t LIKE 'RVW' THEN  0.3 -- Radfahren auf verkehrsarmen Wegen
				WHEN current_lane.cycle_infrastructure_t LIKE 'WSTR' THEN 0.3-- Radfahren in Wohnstrassen
				WHEN current_lane.cycle_infrastructure_t LIKE 'RFGE_N' THEN  0.4 -- Radfahren gegen die Einbahn (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_t LIKE 'TRR' THEN  0.4 -- Treppe auch fuer Radfahrer geeignet
				WHEN current_lane.cycle_infrastructure_t LIKE 'VK_BE' THEN  0.4 -- Verkehrsberuhigte Bereiche
				WHEN current_lane.cycle_infrastructure_t LIKE 'RR' THEN  0.45 -- Radroute (beschilderte Route, Radverkehr wird im Mischverkehr gefuehrt)
				WHEN current_lane.cycle_infrastructure_t LIKE 'GRW_MO' THEN 0.45 -- Gemischter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.cycle_infrastructure_t LIKE 'FUZO_N' THEN 0.5 -- Radfahren in Fussgaengerzonen (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_t LIKE 'GRW_M' THEN 0.5 -- Gemischter Geh- und Radweg
				WHEN current_lane.cycle_infrastructure_t LIKE 'BS'  THEN 0.6 -- Radfahren auf Busspuren
				WHEN current_lane.cycle_infrastructure_t LIKE 'RFUE' THEN 0.7 -- Radfahrerueberfahrt -- weil keine Ahnung...
				WHEN current_lane.cycle_infrastructure_t LIKE 'WSTR_N' THEN  0.7 -- Radfahren in Wohnstrassen (Nebenfahrbahn)
				WHEN current_lane.cycle_infrastructure_t LIKE 'RWO' THEN  0.8 -- Radweg ohne Benuetzungspflicht
				WHEN current_lane.cycle_infrastructure_t LIKE 'SGT' THEN 0.9 -- Singletrail 
				WHEN current_lane.cycle_infrastructure_t LIKE 'GRW_TO' THEN  0.9 -- Getrennter Geh- und Radweg ohne Benuetzungspficht
				WHEN current_lane.cycle_infrastructure_t LIKE 'GRW_T' THEN  1 -- Getrennter Geh- und Radweg
				WHEN current_lane.cycle_infrastructure_t LIKE 'RRN' THEN  1 -- Hauptradroute
				WHEN current_lane.cycle_infrastructure_t LIKE 'RW' THEN  1 -- Baulicher Radweg
				WHEN current_lane.cycle_infrastructure_t LIKE 'RF' THEN  1 -- Radfahrstreifen
				WHEN current_lane.cycle_infrastructure_t LIKE 'MTB' THEN 1 -- Mountainbikestrecke (im Wald). 
				WHEN current_lane.cycle_infrastructure_t LIKE 'FRS'  THEN 1 -- Fahrradstrasse
				WHEN current_lane.cycle_infrastructure_t LIKE 'FE' THEN NULL
				WHEN current_lane.cycle_infrastructure_t LIKE 'HI_IV' THEN NULL
				WHEN current_lane.cycle_infrastructure_t LIKE '-1'  THEN 0
				WHEN current_lane.cycle_infrastructure_t IS NULL THEN 0
			END;
		IF (v_indicator <= v_indicator_help AND v_indicator IS NOT NULL) THEN
			UPDATE normalized_risk_values SET cycle_infrastructure = v_indicator WHERE fid = v_fid;
		ELSE
			UPDATE normalized_risk_values SET cycle_infrastructure = v_indicator_help WHERE fid = v_fid;
		END IF;	
				
		
	
	END LOOP;

END;
$$ LANGUAGE 'plpgsql'
