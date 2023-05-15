SET search_path = 's1078788', 'public';
DROP FUNCTION IF EXISTS construct_lanes(integer);
CREATE OR REPLACE FUNCTION construct_lanes(integer) 
RETURNS void AS $$ 
  DECLARE
     node_id ALIAS FOR $1;
	 lnes_tow INTEGER;
	 lnes_bkw INTEGER;
	 lnes_total INTEGER;
	 oneway_cr INTEGER;
	 width DOUBLE PRECISION;
	 single_lane_width DOUBLE PRECISION;
	 basetyp INTEGER;
	 linearuse_objectid BIGINT;
	 linearuse linearuse_ogd_aoi%ROWTYPE;
	 links gip_linknetz_ogd_aoi%ROWTYPE;
	 linkn_id BIGINT;
	 no_linearuses INTEGER;
	 edg_id BIGINT;
	 links_geo GEOMETRY;
	 lineuse_geo GEOMETRY;
	 lineuse_buff_geom GEOMETRY;
	 offset_lane_bkw DOUBLE PRECISION := 0;
	 offset_lane_tow DOUBLE PRECISION := 0;
	 node_edgedegree integer;
	 one_way BOOL := false; -- boolean that is set to true in case it is a one-way street
	 one_way_direction BOOL; -- which direction leads the one way street? true=tow, false=bkw

  BEGIN
	-- get number of linearuses connected to the node
	 no_linearuses := (SELECT COUNT(l.*) FROM linearuse_ogd_aoi l, edge_ogd_aoi e 
							WHERE l.edge_id = e.objectid 
					   			AND (e.nodefromid = node_id OR e.nodetoid = node_id));
	 -- get number of edges connected to the node
	 node_edgedegree := (SELECT n.edgedegree FROM node_ogd_aoi n 
						 WHERE n.objectid = node_id);
	 
	 RAISE NOTICE 'No linearuses: %', no_linearuses;
	 
	--formerly: creating table (linearuse_lanes) that holds the information of the lanes
	--now: the table is created in the setup-script. 
	-- there, former created information is deleted so it can be newly filled again
	DELETE FROM linearuse_lanes CASCADE;
	
	 
	--	LOOP through the linearuses
	FOR q IN 1..no_linearuses LOOP
		linearuse :=NULL;
		 -- get one linearuse of the intersection
		SELECT INTO linearuse l.* FROM linearuse_ogd_aoi l, edge_ogd_aoi e 
		WHERE l.edge_id = e.objectid AND (
			e.nodefromid = node_id OR e.nodetoid = node_id)
		ORDER BY l.objectid
		LIMIT 1 OFFSET (q-1);

		
		-- find out about its basetype 
		basetyp := linearuse.basetype;
		RAISE NOTICE 'Basetyp: %',basetyp;
		
		-- get basic information
		linearuse_objectid := linearuse.objectid;
		edg_id := linearuse.edge_id;



--- if it is a driving lane (basetype=1) we have to deal with it differently: ----
		IF(linearuse.basetype=1) THEN
		
		-- we determine the width of the street based on 
		-- whether there is a parking strip next to it or not
		-- because: the parking strip is part of the roadway. 
		-- as such, they are part of the street and its width (widthaverage)
		-- if there is a parking strip, the "true" width of the lanes is stored in widthmin
			IF (parking_strip_nearby(edg_id) = true) THEN -- refers to other function
				width := linearuse.widthmin;
				RAISE NOTICE 'parking strip nearby is true.\nTherefore width is %', width;
			ELSE
				width := linearuse.widthaverage;
				RAISE NOTICE 'parking lane nearby is false.\nTherefore width is %', width;
			END IF;

		
		-- check whether it is a deadend
		-- because if it is, the query has to be slightly different
			IF (node_edgedegree > 1) THEN 
			-- select the link that the recent linearuse is connected with into var links
			SELECT INTO links li.*
				FROM linearuse_ogd_aoi lu, gip_linknetz_ogd_aoi li, node_ogd_aoi n, 
					edge_ogd_aoi e, turnuse_ogd_aoi tu
				WHERE lu.edge_id=e.objectid
				AND li.edge_id = e.objectid
				AND (li.from_node = n.objectid OR li.to_node = n.objectid)
				AND n.objectid=node_id
				AND lu.objectid = linearuse_objectid
				AND (lu.objectid = tu.use_to_id OR lu.objectid = tu.use_from_id) 
				-- the next line leaves out elements that don't belong to the junction 
				-- (parking strips, traffic islands, ...)
				AND tu.via_node_id=n.objectid; 
			
			-- IF IT IS a dead end...
			ELSIF (node_edgedegree = 1) THEN 
			SELECT INTO links li.*
				FROM linearuse_ogd_aoi lu, gip_linknetz_ogd_aoi li, node_ogd_aoi n, edge_ogd_aoi e, turnuse_ogd_aoi tu
				WHERE lu.edge_id=e.objectid
				AND li.edge_id = e.objectid
				AND (li.from_node = n.objectid OR li.to_node = n.objectid)
				AND n.objectid=node_id
				AND lu.objectid = linearuse_objectid
				AND (lu.objectid = tu.use_to_id OR lu.objectid = tu.use_from_id);  
			END IF;
			
			RAISE NOTICE 'link id %', links.link_id;
			RAISE NOTICE 'lu_objectid %', linearuse_objectid;
			
			-- storing information about the link id, number of driving lanes 
			-- ... and if it is a one-way street
			linkn_id := links.link_id;
			lnes_tow := links.lanes_tow; -- # linearuses directed in the digitalization dir.
			RAISE NOTICE 'lanes tow: %', lnes_tow;
			lnes_bkw := links.lanes_bkw; -- # linearuses directed against the dig. dir.
			RAISE NOTICE 'lanes bkw: %', lnes_bkw;
			oneway_cr := links.oneway_car;
			RAISE NOTICE 'oneway: %', oneway_cr;
			-- geometry
			links_geo := links.geom;
			
			--finding out, how many (car) lanes there are in total
			IF (lnes_tow > 0 AND lnes_bkw > 0) THEN
				lnes_total := lnes_tow+lnes_bkw;
			ELSIF (lnes_tow > 0 AND lnes_bkw <= 0) THEN
				lnes_total := lnes_tow;
				one_way := true;
				one_way_direction := true; -- one way street is in direction tow
			ELSIF (lnes_tow <= 0 AND lnes_bkw > 0) THEN
				lnes_total := lnes_bkw;
				one_way := true;
				one_way_direction := false; -- one way street is in direction bkw
			END IF;
			RAISE NOTICE 'total number of lanes: % and width: % for linkuse %', 
				lnes_total, width, linearuse_objectid;
			
			--getting the width of a single driving lane
			single_lane_width := width/lnes_total;
			
			--setting the offset variables back to zero
			offset_lane_bkw := 0;
			offset_lane_tow := 0;
			
			--in case it is not oneway streets 
			IF (one_way = false) THEN
			
				--finding out about the single lane's position and buffering
				--first for the direction bkw
				FOR j IN 0..lnes_bkw-1 LOOP
					lineuse_buff_geom := NULL;
					lineuse_geo := NULL;
					-- calculate the lane's offset
					IF (j=0) THEN
						-- if it is the first round, the offset is half the lane's width 
						offset_lane_bkw := offset_lane_bkw + (single_lane_width/2);
						RAISE NOTICE 'offset_lane_bkw % in pass i= %', offset_lane_bkw, j;
					ELSE
						-- if it is the >=2nd round, the offset is the lane's full width
						offset_lane_bkw := offset_lane_bkw + single_lane_width;
						RAISE NOTICE 'offset_lane_bkw % in pass i= %', offset_lane_bkw, j;
					END IF;
					
					-- create the 2D geometry: the original 1D geometry of linearuse_ogd_aoi is
					-- taken, then it is transformed into a local coordinate reference system,
					-- after that, the geometry is shifted by the determined offset
					-- finally, the lane is made 2d by creating a buffer around it 
					-- (size of lanewidth/2)
					lineuse_buff_geom := ST_Buffer(ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
																  offset_lane_bkw, 'quad_segs=4 join=round'),
												   single_lane_width/2,'endcap=square');
					
					-- create the 1D geometry: the oridinal 1D geometry of linearuse_ogd_aoi is 
					-- taken, then it is transformed into a local coordinate reference system,
					-- after that, the geometry is shifted by the determined offset
					-- finally, its direction is reversed. 
					-- this has to be done because ST_offsetCurve turns the original geometry
					lineuse_geo := ST_Reverse(ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
															 offset_lane_bkw, 'quad_segs=4 join=round')
											 );
					
					-- insert the values and calculated geometries into the table linearuse_lanes
					INSERT INTO linearuse_lanes(lu_objectid, link_id, basetype, lane_offset, 
												width, lu_geom,geom, lanes_bkw, lanes_tow, 
												lanes_total, leads_to, comes_from) 
						VALUES (linearuse_objectid, linkn_id, basetyp, offset_lane_bkw, 
								single_lane_width, lineuse_geo, lineuse_buff_geom, lnes_bkw, lnes_tow, 
								lnes_total, links.from_node, links.to_node);
				
				END LOOP;
				
				
				------- and now basically the same for the direction tow ---------
				FOR k IN 0..lnes_tow-1 LOOP
					lineuse_buff_geom := NULL;
					lineuse_geo := NULL;
					IF (k=0) THEN
						offset_lane_tow := offset_lane_tow - (single_lane_width/2);
						RAISE NOTICE 'offset_lane_tow % at pass i= %', offset_lane_tow, k;				
					ELSE
						offset_lane_tow := offset_lane_tow - single_lane_width;
					END IF;
					
					lineuse_buff_geom := ST_Buffer(ST_OffsetCurve(ST_Transform(
						linearuse.geom, 31259), offset_lane_tow, 'quad_segs=4 join=round'), 
												   single_lane_width/2, 'endcap=square');
					lineuse_geo := ST_Reverse(ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
															 offset_lane_tow, 'quad_segs=4 join=round')
											 );
	
					RAISE NOTICE 'geom: %',lineuse_buff_geom;
					
					INSERT INTO linearuse_lanes(lu_objectid, link_id, basetype, 
												lane_offset, width, lu_geom, 
												geom, leads_to, comes_from) 
						VALUES (linearuse_objectid, linkn_id, basetyp, offset_lane_tow, 
								single_lane_width, lineuse_geo, lineuse_buff_geom, 
								links.to_node, links.from_node);
					
				END LOOP;
				
			
			ELSE -- in case it is a one way street --------------------
				

				FOR p IN 0..lnes_total-1 by 1 LOOP
				
					IF (p = 0) THEN
						IF (lnes_total % 2 = 0) THEN
						 -- if it is of an even number of lanes, 
						 -- an initial offset of half a lane's width is needed
							offset_lane_tow := single_lane_width / 2;
						END IF;
					ELSE
						IF (p % 2 = 0) THEN
							offset_lane_tow := offset_lane_tow + (single_lane_width * p);
						ELSIF (p % 2 = 1) THEN
							offset_lane_tow := offset_lane_tow + (single_lane_width * p * (-1));
						END IF;
					END IF;
					
					RAISE NOTICE 'In pass % there is an Offset of %', p, offset_lane_tow ;
					
					lineuse_buff_geom := ST_Buffer(ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
																  offset_lane_tow, 'quad_segs=4 join=round'),
												   single_lane_width/2,'endcap=square');
					
					
					-- problem is, that ST_OffsetCurve changes the direction of lines 
					-- that were created with the help of negative distances. 
					-- In a one way street we naturally want all the streets to head in the 
					-- same direction. Therefore an if-else building needs to be constructed.
					
					 -- if the linearuse geometry of the one way street is headed in the same
					 -- direction as the edge it belongs to, ...
					IF (lnes_tow > 0) THEN
					-- ... we need to reverse the geometry of those lanes 
					-- with a negative distance
						IF (offset_lane_tow < 0) THEN
							lineuse_geo := ST_Reverse(ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
																	 offset_lane_tow, 
																	 'quad_segs=4 join=round'));
						 -- ... for the others, we don't need to reverse them
						ELSE
							lineuse_geo := ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
														  offset_lane_tow, 'quad_segs=4 join=round');
						END IF;
					
					-- if the linearuse geometry of the one way street is headed in the 
					-- opposite direction of the edge it belongs to...
					ELSIF (lnes_bkw > 0) THEN 
					-- ... the ones we do not need to reverse the lane's geometry because 
					-- of the negative distance they are reversed anyway
						IF (offset_lane_tow < 0) THEN 
							lineuse_geo := ST_OffsetCurve(ST_Transform(linearuse.geom, 31259), 
														  offset_lane_tow, 'quad_segs=4 join=round');
						 -- however, those geometries that have a positive distance 
						 -- to the original linearuse, need to be turned now
						ELSE
							lineuse_geo := ST_Reverse(ST_OffsetCurve(ST_Transform(
								linearuse.geom, 31259), offset_lane_tow, 'quad_segs=4 join=round'));
						END IF;
					END IF;
					
					-- to keep the attributive integrity, leads_to and comes_from 
					-- need to be adapted f the oneway streets are in the same 
					-- direction as the link (gip_linknetz)
					IF (one_way_direction = TRUE) THEN 
						INSERT INTO linearuse_lanes(lu_objectid, link_id, basetype, lane_offset, 
													width, lu_geom, geom, leads_to, comes_from) 
							VALUES (linearuse_objectid, linkn_id, basetyp, offset_lane_tow, 
									single_lane_width, lineuse_geo, lineuse_buff_geom, 
									links.to_node, links.from_node);
					ELSIF (one_way_direction = FALSE) THEN
						INSERT INTO linearuse_lanes(lu_objectid, link_id, basetype, lane_offset, 
													width, lu_geom, geom, leads_to, comes_from) 
							VALUES (linearuse_objectid, linkn_id, basetyp, offset_lane_tow, 
									single_lane_width, lineuse_geo, lineuse_buff_geom, 
									links.from_node, links.to_node);
					END IF;
					
				END LOOP;
			
			END IF;
	

------------------------------------------------------------------------------			
			
		-- IF IT IS NOT A DRIVING LANE, THEN CHECK WHETHER 
		-- IT IS AN OTHER RELEVANT BASETYPE OF LINEARUSE	
		-- path ways: 7, 21, 37, 41   -- cycle lanes: 2, 22, 23, 31, 33, 35, 36
		ELSIF (linearuse.basetype IN (2, 7, 21, 22, 23, 35, 36)) THEN
			
			-- get width of the geometry
			width := linearuse.widthaverage;
			-- 2D geometry: build buffer around it 
			lineuse_buff_geom := ST_Buffer(ST_Transform(linearuse.geom, 31259), 
										   width/2,'endcap=square');
			-- 1D geometry: transform it to local crs
			lineuse_geo := ST_Transform(linearuse.geom,31259);
			
			-- insert results in table linearuse_lanes
			-- note: leads_to and comes_from are attributes that are not really needed 
				-- here, as sidewalks do not have a driving direction
			INSERT INTO linearuse_lanes(lu_objectid, link_id, basetype, lane_offset, 
										width, lu_geom, geom, leads_to, comes_from) 
					VALUES (linearuse_objectid, linkn_id, basetyp, 0, width, lineuse_geo, 
							lineuse_buff_geom, links.to_node, links.from_node);
					

		END IF;

	
	END LOOP;

  END;
$$ LANGUAGE 'plpgsql';	

 