SET search_path = 's1078788', 'public';
DROP FUNCTION IF EXISTS setup();
CREATE OR REPLACE FUNCTION setup() 
RETURNS void AS $$ 

	--DECLARE
	BEGIN
	
		-- 1st step table: create table that holds the linearuse_lanes for storing constructed lanes
		DROP TABLE IF EXISTS linearuse_lanes CASCADE; 
		CREATE TABLE linearuse_lanes(fid serial PRIMARY KEY,
			lu_objectid bigint, 
			link_id bigint,
			geom geometry,
			basetype integer,
			lane_offset double precision,
			width double precision,
			lu_geom geometry,
			lanes_bkw integer,
			lanes_tow integer, 
			lanes_total integer,
			leads_to bigint,
			comes_from bigint,
			CONSTRAINT linearuselanes_luobjectid_fkey FOREIGN KEY(lu_objectid) REFERENCES linearuse_ogd_aoi(objectid),
			CONSTRAINT linearuselanes_linkid_fkey FOREIGN KEY(link_id) REFERENCES gip_linknetz_ogd_aoi(link_id),
			CONSTRAINT linearuselanes_leadsto_fkey FOREIGN KEY(leads_to) REFERENCES node_ogd_aoi(objectid),
			CONSTRAINT linearuselanes_comesfrom_fkey FOREIGN KEY(comes_from) REFERENCES node_ogd_aoi(objectid),
			CONSTRAINT linearuselanes_basetype_fkey FOREIGN KEY (basetype) REFERENCES lut_basetype(id)	
		);
	
	
		--2nd step table: it holds the results of the turnuse creation
		DROP TABLE IF EXISTS iplateau CASCADE;
  		CREATE TABLE iplateau(
			fid SERIAL PRIMARY KEY,
			turnuse_objectid bigint,
			node_id bigint,
			turnuse_geom geometry,
			turnuse_buff_geom geometry,
			curved_geom geometry,
			start_point_geom geometry,
			end_point_geom geometry,
			linearuse_start_id bigint,
			linearuse_end_id bigint,
			start_width double precision,
			end_width double precision,
			basetype integer,
			intermediate_point geometry,
			el_geom1 geometry,
			el_geom2 geometry,
			CONSTRAINT iplateau_turnuseobjectid_fkey FOREIGN KEY (turnuse_objectid) REFERENCES turnuse_ogd_aoi(objectid),
			CONSTRAINT iplateau_nodeid_fkey FOREIGN KEY (node_id) REFERENCES node_ogd_aoi(objectid),
			CONSTRAINT iplateau_lustart_fkey FOREIGN KEY (linearuse_start_id) REFERENCES linearuse_lanes(fid),
			CONSTRAINT iplateau_luend_fkey FOREIGN KEY (linearuse_end_id) REFERENCES linearuse_lanes(fid),
			CONSTRAINT iplateau_basetype_fkey FOREIGN KEY (basetype) REFERENCES lut_basetype(id)			
		);
		
	
		--3rd step: it holds the parking lanes
		DROP TABLE IF EXISTS parking_strips CASCADE;
		CREATE TABLE parking_strips(
			fid serial primary key,
			line_geom geometry,
			edge_id bigint,
			buffered_geom geometry, 
			width double precision,
			CONSTRAINT parkingstrips_fid_fkey FOREIGN KEY(fid) REFERENCES linearuse_lanes(fid),
			CONSTRAINT parkingstrips_edgeid_fkey FOREIGN KEY (edge_id) REFERENCES edge_ogd_aoi(objectid)
		);
		
		-- 4th step: table that holds the data that is obtained with the helper functions.
		DROP TABLE IF EXISTS risk_value_table;
		CREATE TABLE IF NOT EXISTS risk_value_table (
			fid integer PRIMARY KEY,
			nodeid bigint,
			turnuse_objectid bigint,
			basetype integer, 
			urban boolean,
			rails boolean,
			traffic_lights boolean,
			intersection_legs integer,
			intersection_angle integer, 
			speed integer, 
			traffic_volume integer,
			lane_number_cars integer, 
			lane_number_bikes integer,
			gradient real,
			barriers integer,
			street_type boolean, 
			street_condition integer,
			round_about_inner_circle integer, 
			round_about boolean,
			round_about_cycle_infstr boolean,
			mixed_traffic_f varchar(10),
			mixed_traffic_t varchar(10),
			cycle_infrastructure_f varchar(45),
			cycle_infrastructure_t varchar(45),
			CONSTRAINT riskvaluetable_fid_fkey FOREIGN KEY (fid) REFERENCES iplateau(fid),
			CONSTRAINT riskvaluetable_nodeid_fkey FOREIGN KEY (nodeid) REFERENCES node_ogd_aoi(objectid),
			CONSTRAINT riskvaluetable_turnuseobjectid_fkey FOREIGN KEY (turnuse_objectid) REFERENCES turnuse_ogd_aoi(objectid)
		);
			
		-- 5th step: the normalized values (0-1) are stored in here.	
		DROP TABLE IF EXISTS normalized_risk_values;
		CREATE TABLE normalized_risk_values (
			fid integer PRIMARY KEY, 
			nodeid bigint,
			urban numeric,
			rails numeric,
			traffic_lights numeric,
			intersection_legs numeric,
			speed numeric,
			lane_number_cars numeric,
			lane_number_bikes numeric,
			gradient numeric,
			street_type numeric,
			round_about_inner_circle numeric,
			round_about numeric,
			round_about_cycle_infstr numeric,
			mixed_traffic numeric,
			cycle_infrastructure numeric,
			CONSTRAINT normalizedriskvalues_fid_fkey FOREIGN KEY(fid) REFERENCES iplateau(fid),
			CONSTRAINT normalizedriskvalues_nodeid_fkey FOREIGN KEY (nodeid) REFERENCES node_ogd_aoi(objectid)
		);
		
		--6th step: the finished lanes (weighted and normalized in 1D)
		DROP TABLE IF EXISTS weighted_turnuses;
		CREATE TABLE weighted_turnuses (
			fid integer PRIMARY KEY,
			geom geometry(Linestring, 3857),
			risk_factor numeric,
			CONSTRAINT weightedturnuses_fid_fkey FOREIGN KEY(fid) REFERENCES iplateau(fid)
		);	
	
	
	
	END;
$$ LANGUAGE 'plpgsql';