BEGIN;
CREATE TYPE operational_state AS ENUM ('COMMISSIONING','NOMINAL','SAFE_MODE','DEGRADED','OFFLINE');
CREATE TYPE communication_mode AS ENUM ('TT&C','SSTV','Codec2','M17');
CREATE TYPE queue_status AS ENUM ('QUEUED','TRANSMITTING','DELIVERED','FAILED','EXPIRED');
CREATE TYPE pass_status AS ENUM ('SCHEDULED','ACTIVE','COMPLETED','MISSED');

CREATE TABLE satellites (
  id BIGSERIAL PRIMARY KEY, name VARCHAR(80) UNIQUE NOT NULL, norad_id VARCHAR(20),
  operational_state operational_state NOT NULL DEFAULT 'COMMISSIONING', orbit_number INTEGER NOT NULL DEFAULT 0,
  uptime_label VARCHAR(30) NOT NULL DEFAULT '0d 00h', launched_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE deployers (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL, release_mechanism VARCHAR(80) NOT NULL, state VARCHAR(30) NOT NULL,
  separation_confirmed BOOLEAN NOT NULL DEFAULT false, separation_confirmed_at TIMESTAMPTZ,
  CONSTRAINT confirmation_requires_time CHECK (NOT separation_confirmed OR separation_confirmed_at IS NOT NULL)
);
CREATE TABLE deployment_events (
  id BIGSERIAL PRIMARY KEY,
  deployer_id BIGINT NOT NULL REFERENCES deployers(id) ON DELETE RESTRICT,
  satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  event_number INTEGER NOT NULL CHECK(event_number > 0),
  scheduled_at TIMESTAMPTZ, initiated_at TIMESTAMPTZ, confirmed_at TIMESTAMPTZ,
  deployment_status VARCHAR(20) NOT NULL CHECK(deployment_status IN ('SCHEDULED','RELEASED','CONFIRMED','FAILED','PARTIAL','ABORTED')),
  confirmation_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(confirmation_status IN ('PENDING','RECEIVED','MISSING','NOT_REQUIRED')),
  confirmation_method VARCHAR(100), notes TEXT,
  UNIQUE(deployer_id, satellite_id, event_number),
  CHECK(confirmed_at IS NULL OR initiated_at IS NULL OR confirmed_at >= initiated_at)
);
CREATE TABLE ground_stations (
  id BIGSERIAL PRIMARY KEY, code VARCHAR(16) UNIQUE NOT NULL, name VARCHAR(100) NOT NULL, city VARCHAR(100) NOT NULL,
  latitude NUMERIC(9,6), longitude NUMERIC(9,6), status VARCHAR(24) NOT NULL DEFAULT 'READY',
  signal_percent SMALLINT NOT NULL DEFAULT 0 CHECK(signal_percent BETWEEN 0 AND 100),
  elevation_deg NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK(elevation_deg BETWEEN 0 AND 90),
  next_pass_label VARCHAR(80) DEFAULT 'Calculating…', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE communication_modes (
  id SMALLSERIAL PRIMARY KEY, mode communication_mode UNIQUE NOT NULL, bitrate_bps INTEGER NOT NULL CHECK(bitrate_bps > 0),
  power_cost_w NUMERIC(5,2) NOT NULL CHECK(power_cost_w > 0), description TEXT NOT NULL
);
CREATE TABLE payloads (
  id BIGSERIAL PRIMARY KEY,
  satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  payload_type VARCHAR(30) NOT NULL CHECK(payload_type IN ('TT&C_HOUSEKEEPING','DIGITAL_VOICE','SSTV_IMAGING','MULTI_MODE','OTHER')),
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE','FAULT','TESTING')),
  power_rating_w NUMERIC(7,3) CHECK(power_rating_w IS NULL OR power_rating_w >= 0),
  description TEXT,
  UNIQUE(satellite_id,name), UNIQUE(id,satellite_id)
);
CREATE TABLE payload_communication_modes (
  payload_id BIGINT NOT NULL REFERENCES payloads(id) ON DELETE CASCADE,
  communication_mode_id SMALLINT NOT NULL REFERENCES communication_modes(id) ON DELETE RESTRICT,
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY(payload_id,communication_mode_id)
);
CREATE TABLE station_communication_modes (
  station_id BIGINT NOT NULL REFERENCES ground_stations(id) ON DELETE CASCADE,
  communication_mode_id SMALLINT NOT NULL REFERENCES communication_modes(id) ON DELETE RESTRICT,
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY(station_id,communication_mode_id)
);
CREATE TABLE telemetry (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  battery_percent NUMERIC(5,2) NOT NULL CHECK(battery_percent BETWEEN 0 AND 100), temperature_c NUMERIC(6,2) NOT NULL,
  link_quality SMALLINT NOT NULL CHECK(link_quality BETWEEN 0 AND 100), storage_percent NUMERIC(5,2) NOT NULL CHECK(storage_percent BETWEEN 0 AND 100),
  power_draw_w NUMERIC(5,2) NOT NULL CHECK(power_draw_w >= 0), rssi_dbm NUMERIC(6,2), snr_db NUMERIC(6,2),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE ground_passes (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  station_id BIGINT NOT NULL REFERENCES ground_stations(id) ON DELETE CASCADE, aos_at TIMESTAMPTZ NOT NULL,
  los_at TIMESTAMPTZ NOT NULL, max_elevation_deg NUMERIC(5,2) CHECK(max_elevation_deg BETWEEN 0 AND 90),
  status pass_status NOT NULL DEFAULT 'SCHEDULED', CHECK(los_at > aos_at), UNIQUE(satellite_id, station_id, aos_at)
);
CREATE TABLE data_queue (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  mode communication_mode NOT NULL, label VARCHAR(140) NOT NULL, payload_type VARCHAR(40) NOT NULL,
  size_kb INTEGER NOT NULL CHECK(size_kb > 0), urgency SMALLINT NOT NULL CHECK(urgency BETWEEN 0 AND 100),
  priority_score SMALLINT NOT NULL CHECK(priority_score BETWEEN 0 AND 100), deadline_at TIMESTAMPTZ,
  deadline_label VARCHAR(60), status queue_status NOT NULL DEFAULT 'QUEUED', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE routing_decisions (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  pass_id BIGINT REFERENCES ground_passes(id) ON DELETE SET NULL, queue_item_id BIGINT REFERENCES data_queue(id) ON DELETE SET NULL,
  selected_mode communication_mode NOT NULL, confidence SMALLINT NOT NULL CHECK(confidence BETWEEN 0 AND 100),
  score SMALLINT NOT NULL CHECK(score BETWEEN 0 AND 100), battery_snapshot NUMERIC(5,2) NOT NULL,
  link_snapshot SMALLINT NOT NULL CHECK(link_snapshot BETWEEN 0 AND 100), reason TEXT NOT NULL,
  policy_version VARCHAR(30) NOT NULL, overridden BOOLEAN NOT NULL DEFAULT false, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE routing_decision_items (
  id BIGSERIAL PRIMARY KEY,
  routing_decision_id BIGINT NOT NULL REFERENCES routing_decisions(id) ON DELETE CASCADE,
  queue_item_id BIGINT NOT NULL REFERENCES data_queue(id) ON DELETE RESTRICT,
  selected_mode communication_mode,
  transmission_order SMALLINT CHECK(transmission_order IS NULL OR transmission_order > 0),
  priority_score NUMERIC(6,2) CHECK(priority_score IS NULL OR priority_score BETWEEN 0 AND 100),
  action VARCHAR(20) NOT NULL CHECK(action IN ('TRANSMIT','DEFER','REJECT')),
  reason TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK(action <> 'TRANSMIT' OR (selected_mode IS NOT NULL AND transmission_order IS NOT NULL)),
  UNIQUE(routing_decision_id,queue_item_id), UNIQUE(routing_decision_id,transmission_order)
);
CREATE TABLE commands (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  station_id BIGINT REFERENCES ground_stations(id) ON DELETE SET NULL, command_type VARCHAR(60) NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}', status VARCHAR(24) NOT NULL DEFAULT 'PENDING', issued_by VARCHAR(100) NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(), acknowledged_at TIMESTAMPTZ
);
CREATE TABLE transmission_logs (
  id BIGSERIAL PRIMARY KEY, satellite_id BIGINT NOT NULL REFERENCES satellites(id) ON DELETE CASCADE,
  station_id BIGINT REFERENCES ground_stations(id) ON DELETE SET NULL, queue_item_id BIGINT REFERENCES data_queue(id) ON DELETE SET NULL,
  mode communication_mode NOT NULL, bytes_sent INTEGER NOT NULL CHECK(bytes_sent >= 0), packets_sent INTEGER NOT NULL DEFAULT 0,
  packets_lost INTEGER NOT NULL DEFAULT 0, attempt_number SMALLINT NOT NULL DEFAULT 1 CHECK(attempt_number > 0),
  result VARCHAR(20) NOT NULL DEFAULT 'SUCCESS' CHECK(result IN ('SUCCESS','FAILED','PARTIAL')),
  observed_link_quality NUMERIC(5,2) CHECK(observed_link_quality IS NULL OR observed_link_quality BETWEEN 0 AND 100),
  failure_reason TEXT, started_at TIMESTAMPTZ NOT NULL, ended_at TIMESTAMPTZ,
  CHECK(ended_at IS NULL OR ended_at >= started_at), CHECK(packets_lost <= packets_sent),
  UNIQUE(queue_item_id,station_id,attempt_number)
);
CREATE INDEX idx_telemetry_satellite_time ON telemetry(satellite_id, recorded_at DESC);
CREATE INDEX idx_queue_active_priority ON data_queue(satellite_id, priority_score DESC) WHERE status IN ('QUEUED','TRANSMITTING');
CREATE INDEX idx_pass_station_aos ON ground_passes(station_id, aos_at);
CREATE INDEX idx_decisions_satellite_time ON routing_decisions(satellite_id, created_at DESC);
CREATE INDEX idx_deployment_events_satellite ON deployment_events(satellite_id,event_number DESC);
CREATE INDEX idx_transmission_result_time ON transmission_logs(result,started_at DESC);

CREATE VIEW latest_satellite_telemetry AS SELECT DISTINCT ON (satellite_id) * FROM telemetry ORDER BY satellite_id, recorded_at DESC;
CREATE VIEW pending_data_queue AS
SELECT q.*, s.name AS satellite_name,
  (q.deadline_at IS NOT NULL AND q.deadline_at < now()) AS deadline_passed
FROM data_queue q JOIN satellites s ON s.id=q.satellite_id
WHERE q.status IN ('QUEUED','TRANSMITTING');
CREATE VIEW routing_decision_audit AS
SELECT d.id AS decision_id,d.created_at,d.selected_mode,d.confidence,d.score,d.reason,d.policy_version,d.overridden,
  s.name AS satellite_name,g.name AS station_name,p.aos_at,p.los_at,
  i.id AS decision_item_id,i.queue_item_id,q.label AS queue_label,i.action,i.transmission_order,i.priority_score,i.reason AS item_reason
FROM routing_decisions d JOIN satellites s ON s.id=d.satellite_id
LEFT JOIN ground_passes p ON p.id=d.pass_id LEFT JOIN ground_stations g ON g.id=p.station_id
LEFT JOIN routing_decision_items i ON i.routing_decision_id=d.id LEFT JOIN data_queue q ON q.id=i.queue_item_id;
CREATE VIEW transmission_history AS
SELECT x.id AS transmission_id,x.started_at,x.ended_at,x.attempt_number,x.result,x.bytes_sent,
  x.observed_link_quality,x.failure_reason,x.mode,q.label AS queue_label,g.name AS station_name,s.name AS satellite_name
FROM transmission_logs x JOIN satellites s ON s.id=x.satellite_id
LEFT JOIN data_queue q ON q.id=x.queue_item_id LEFT JOIN ground_stations g ON g.id=x.station_id;
CREATE VIEW mission_performance AS
SELECT s.id AS satellite_id,s.name,
  COALESCE(tx.transmissions,0) AS transmissions,COALESCE(tx.delivery_percent,0) AS delivery_percent,
  COALESCE(ai.avg_ai_confidence,0) AS avg_ai_confidence
FROM satellites s
LEFT JOIN (SELECT satellite_id,count(*) AS transmissions,
  COALESCE(sum(packets_sent-packets_lost)::numeric/NULLIF(sum(packets_sent),0)*100,0)::numeric(5,2) AS delivery_percent
  FROM transmission_logs GROUP BY satellite_id) tx ON tx.satellite_id=s.id
LEFT JOIN (SELECT satellite_id,avg(confidence)::numeric(5,2) AS avg_ai_confidence
  FROM routing_decisions GROUP BY satellite_id) ai ON ai.satellite_id=s.id;
COMMIT;
