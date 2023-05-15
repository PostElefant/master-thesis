-- checks, whether along the edge is a parking lane
-- function returns boolean

-- is given integer (the edge's id)
DROP FUNCTION IF EXISTS parking_strip_nearby(bigint);
CREATE OR REPLACE FUNCTION parking_strip_nearby(bigint) 
RETURNS bool AS $$ 

  DECLARE
  	edg_id ALIAS FOR $1;
  	count_linearuses integer;
	bt integer;
  
  BEGIN
  	-- get the linearuses along the edge
  	count_linearuses := (SELECT COUNT(lu.*) FROM linearuse_ogd_aoi lu 
						 WHERE lu.edge_id = edg_id);
	
	-- loop through them
	FOR q IN 1..count_linearuses LOOP 
		bt := (SELECT lu.basetype
			   FROM linearuse_ogd_aoi lu
			   WHERE lu.edge_id = edg_id
			   ORDER BY lu.objectid
			   OFFSET q - 1
			   LIMIT 1);
		
		-- if the examined linearuse is indeed a parking strip, return true
		IF (bt = 8) THEN 
			RETURN true;
		END IF;
	
	END LOOP;
	
	-- if none of the linearuses was a parking strip, return false
	RETURN false;
  
  END;
$$ LANGUAGE 'plpgsql';	