-- this script executes the functions that make the workflow
-- the script is where all the threads come together.
-- the single parameter given is the node's objectid.
SET search_path = 's1078788', 'public';

-- create tables in which the results will be stored in
SELECT setup();

-- build 1D and 2D representation of the lanes leading to the intersection
SELECT construct_lanes(10355976);

-- create the intersection plateau by creating the turning relations
SELECT build_plateau(10355976);

-- construct the parking lanes and clip them from the driving lanes
SELECT parking(10355976);

-- get information and data about the data
SELECT get_risk_factors(10355976);

-- normalize the data to a scale from 0 (very risky) to 1 (safe)
SELECT normalize_factors();

-- Weighting of the factors, which are then used to calculate the risk index.
-- the parameters correspond to the weights for the factors. Th
-- In the following order, the parameters correspond to the weights:
-- urban, rails, traffic lights, edge degree, speed, # crossed car lanes, 
-- # crossed bike lanes, gradient, street type, round about (ra), ra inner circle,
-- ra cycle infrastructure, cycling infrastructure, mixed traffic
SELECT weighting(0, 0, 0, 0, 0.3, 0.1, 0.1, 0.1, 0, 0.2, 0, 0, 0.2, 0)

-- when all functions have been called, the script add_foreignkeys.sql should be run 
-- to create foreign keys between the permanent and the constantly regenerated tables. 

-- Example Intersections:
-- Intersection A One-way streets: objectid = 10354202
-- Intersection B complicated junction (3-legged): objectid = 10355976
-- Intersection C classic 4-legged junction: objectid = 10355123

-- Other Weighting Schemes:
-- 1 Default-Values: 
-- SELECT weighting(0, 0, 0, 0, 0.3, 0.1, 0.1, 0.1, 0, 0.2, 0, 0, 0.2, 0)
-- 2 local indicators: 
-- SELECT weighting(0, 0, 0, 0, 0, 0.2, 0.2, 0.2, 0, 0, 0, 0, 0.3, 0.1)
-- 3 all values same: 
-- SELECT weighting(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
-- 4 signalisation sim. with def values: 
-- UPDATE risk_value_table SET traffic_lights = true; SELECT normalize_factors(); 
-- SELECT weighting(0, 0, 0.2, 0, 0.3, 0.1, 0.1, 0.1, 0, 0.2, 0, 0, 0.2, 0)
-- 5 speed: 30 km/h, weighting with def. values: 
-- UPDATE risk_value_table SET traffic_lights = false, speed = 30; SELECT normalize_factors(); 
-- SELECT weighting(0, 0, 0, 0, 0.3, 0.1, 0.1, 0.1, 0, 0.2, 0, 0, 0.2, 0)
-- 6 speed: 50 km/h, weighting with def. values: 
-- UPDATE risk_value_table SET speed = 50; SELECT normalize_factors(); 
-- SELECT weighting(0, 0, 0, 0, 0.3, 0.1, 0.1, 0.1, 0, 0.2, 0, 0, 0.2, 0)
	
