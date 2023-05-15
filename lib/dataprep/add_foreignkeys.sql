-- -- Conventions naming: {tablename}_{columnname(s)}_{suffix}

-- table available_turnuses
ALTER TABLE available_turnuses ADD CONSTRAINT availableturnuses_basetype_fkey
FOREIGN KEY (basetype) REFERENCES lut_basetype (id);

ALTER TABLE available_turnuses ADD CONSTRAINT availableturnuses_vianodeid_fkey
FOREIGN KEY (via_node_id) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE available_turnuses ADD CONSTRAINT availableturnuses_usetoid_fkey
FOREIGN KEY (use_to_id) REFERENCES linearuse_ogd_aoi(objectid);

ALTER TABLE available_turnuses ADD CONSTRAINT availableturnuses_usefromid_fkey
FOREIGN KEY (use_from_id) REFERENCES linearuse_ogd_aoi(objectid);


-- table help_turnuses_cars
ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_lfid_fkey
FOREIGN KEY (l_fid) REFERENCES linearuse_lanes(fid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_llfid_fkey
FOREIGN KEY (ll_fid) REFERENCES linearuse_lanes(fid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_lluobjectid_fkey
FOREIGN KEY (l_lu_objectid) REFERENCES linearuse_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_llluobjectid_fkey
FOREIGN KEY (ll_lu_objectid) REFERENCES linearuse_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_basetype_fkey
FOREIGN KEY (basetype) REFERENCES lut_basetype(id);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_lleadsto_fkey
FOREIGN KEY (l_leads_to) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_lcomesfrom_fkey
FOREIGN KEY (l_comes_from) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_llleadsto_fkey
FOREIGN KEY (ll_leads_to) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_llcomesfrom_fkey
FOREIGN KEY (ll_comes_from) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE help_turnuses_cars ADD CONSTRAINT helpturnusescars_nodeid_fkey
FOREIGN KEY (node_id) REFERENCES node_ogd_aoi(objectid);


-- iplateau
ALTER TABLE iplateau ADD CONSTRAINT iplateau_turnuseobjectid_fkey
FOREIGN KEY (turnuse_objectid) REFERENCES turnuse_ogd_aoi(objectid);

ALTER TABLE iplateau ADD CONSTRAINT iplateau_nodeid_fkey
FOREIGN KEY (node_id) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE iplateau ADD CONSTRAINT iplateau_linearusestartid_fkey
FOREIGN KEY (linearuse_start_id) REFERENCES linearuse_lanes(fid)
ON DELETE SET NULL;

ALTER TABLE iplateau ADD CONSTRAINT iplateau_linearuseendid_fkey
FOREIGN KEY (linearuse_end_id) REFERENCES linearuse_lanes(fid)
ON DELETE SET NULL;

ALTER TABLE iplateau ADD CONSTRAINT iplateau_basetype_fkey
FOREIGN KEY (basetype) REFERENCES lut_basetype(id);


-- linearuse_lanes
ALTER TABLE linearuse_lanes ADD CONSTRAINT linearuselanes_luobjectid_fkey
FOREIGN KEY (lu_objectid) REFERENCES linearuse_ogd_aoi(objectid);

ALTER TABLE linearuse_lanes ADD CONSTRAINT linearuselanes_linkid_fkey
FOREIGN KEY (link_id) REFERENCES gip_linknetz_ogd_aoi(link_id);

ALTER TABLE linearuse_lanes ADD CONSTRAINT linearuselanes_basetype_fkey
FOREIGN KEY (basetype) REFERENCES lut_basetype(id);

ALTER TABLE linearuse_lanes ADD CONSTRAINT linearuselanes_leadsto_fkey
FOREIGN KEY (leads_to) REFERENCES node_ogd_aoi(objectid);

ALTER TABLE linearuse_lanes ADD CONSTRAINT linearuselanes_comesfrom_fkey
FOREIGN KEY (comes_from) REFERENCES node_ogd_aoi(objectid);


-- parking_strips
ALTER TABLE parking_strips ADD CONSTRAINT parkingstrips_edgeid_fkey
FOREIGN KEY (edge_id) REFERENCES edge_ogd_aoi(objectid);


-- risk_value_table
ALTER TABLE risk_value_table ADD CONSTRAINT riskvaluetable_turnuseobjectid_fkey
FOREIGN KEY (turnuse_objectid) REFERENCES turnuse_ogd_aoi(objectid);

ALTER TABLE risk_value_table ADD CONSTRAINT riskvaluetable_basetype_fkey
FOREIGN KEY (basetype) REFERENCES lut_basetype(id);

ALTER TABLE risk_value_table ADD CONSTRAINT riskvaluetable_nodeid_fkey
FOREIGN KEY (nodeid) REFERENCES node_ogd_aoi(objectid);

