-- this function is used for constructing the parking lanes
-- it does it for the parking lanes that are along segments leading to 
	-- the intersection under investigation
-- first, it makes the parking lanes 2-dimensional by building a buffer
-- then, it clips the parking strip's geometry from the driving lanes

SET search_path = 's1078788', 'public';
DROP FUNCTION IF EXISTS parking(integer);
CREATE OR REPLACE FUNCTION parking(integer) 
RETURNS void AS $$ 
  DECLARE
  	node_id ALIAS FOR $1;
	parking_linearuse linearuse_ogd_aoi%ROWTYPE;
	width double precision;
	no_parking_strips integer;
	lu_edgeid bigint;
	buffered_geom geometry;
	
	no_linearuse_lanes integer;
	lu_lane linearuse_lanes%ROWTYPE;
	park_strip parking_strips%ROWTYPE;
	lane_wo_park geometry; -- lane without geometry
	
  BEGIN
  	-- get number of parking lanes
  	no_parking_strips := (SELECT COUNT(lu.*) 
						  FROM linearuse_ogd_aoi lu, edge_ogd_aoi e 	
						  WHERE lu.edge_id = e.objectid 
						  	AND lu.basetype = 8 
						  AND (e.nodefromid = node_id OR e.nodetoid = node_id));
  
  	-- formerly, the table parking_strips was created here. 
	-- however, this was outsourced to the setup() script
  	DELETE FROM parking_strips;

	-- loop through all parking strips that are connected to edges leading to the intersection
	FOR q in 1..no_parking_strips LOOP
	
		-- take one parking strip and store it in the variable parking_linearuse
		SELECT INTO parking_linearuse lu.*
		FROM linearuse_ogd_aoi lu, edge_ogd_aoi e
		WHERE lu.edge_id = e.objectid
			AND lu.basetype = 8
			AND (e.nodefromid = node_id
				OR e.nodetoid = node_id)
		ORDER BY lu.objectid 
		LIMIT 1
		OFFSET (q-1);
		
		RAISE NOTICE 'line geom: %', parking_linearuse.geom;
		
		lu_edgeid := parking_linearuse.edge_id;
		
		-- build a buffer around the parking strip in question. 
		-- Calculate the buffer's width from the strip's attribute widthaverage
		buffered_geom := ST_Buffer(ST_Transform(parking_linearuse.geom, 31259), parking_linearuse.widthaverage/2 ,'endcap=square');
		
		-- store the geometry that was just created in the table parking_strips. 
		-- Attributes: original geometry, buffered geometry, the geom's width, 
		-- the edge's ID it belongs to
		INSERT INTO parking_strips (line_geom, buffered_geom, width, edge_id)
		VALUES (ST_Transform(parking_linearuse.geom, 31259), buffered_geom, 
				parking_linearuse.widthaverage, lu_edgeid);
		
			
	END LOOP;
	
	
	
	------ CLIPPING -------
	-- the clipping part clips elements of the linearuse_lanes table. 
	-- this is done because it happened that the road's width included the parking strip.
	-- This widens the lane immensely and distorts the model. 
	-- For this reason, this function cuts out the parking strip from the lane.
	
	no_linearuse_lanes := (SELECT COUNT(*) FROM linearuse_lanes);
	
	-- go through all lanes
	FOR r in 1..no_linearuse_lanes LOOP
		
		-- store it in the variable lu_lane
		SELECT INTO lu_lane lul.*
		FROM linearuse_lanes lul
		ORDER BY lul.fid
		LIMIT 1
		OFFSET (r-1);
		
		-- go through all parking strips
		FOR s in 1..no_parking_strips LOOP
			
			-- store it in the variable park_strip
			SELECT INTO park_strip ps.* 
			FROM parking_strips ps
			ORDER BY fid
			LIMIT 1
			OFFSET (s-1);
			
			-- if the lane and the parking strip intersect...
			IF (ST_Intersects(lu_lane.geom, park_strip.buffered_geom)) THEN
				
				-- ... build the difference (lane - parking strip). store it in the var lane_wo_park
				lane_wo_park := ST_Difference(lu_lane.geom, park_strip.buffered_geom);
				
				-- update the table linearuse_lanes by replacing the old with the new geometry
				UPDATE linearuse_lanes 
				SET geom = lane_wo_park
				WHERE fid = lu_lane.fid;
			
			
			END IF;
		
		END LOOP;
		
	END LOOP;	
	
  END;
$$ LANGUAGE 'plpgsql';	