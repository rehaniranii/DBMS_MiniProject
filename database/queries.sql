-- SomaiyaSat DBMS demonstration queries
-- Run after schema.sql and seed.sql.

-- 1. Latest telemetry for every satellite (DISTINCT ON view).
SELECT s.name, t.recorded_at, t.battery_percent, t.temperature_c,
       t.link_quality, t.power_draw_w
FROM latest_satellite_telemetry t
JOIN satellites s ON s.id = t.satellite_id
ORDER BY s.name;

-- 2. Priority-ordered data waiting for downlink.
SELECT id, satellite_name, mode, label, size_kb, priority_score,
       deadline_at, deadline_passed
FROM pending_data_queue
ORDER BY priority_score DESC, created_at;

-- 3. Explainable AI decision audit with packet-level outcomes.
SELECT decision_id, created_at, satellite_name, station_name,
       selected_mode, confidence, queue_label, action,
       transmission_order, priority_score, item_reason
FROM routing_decision_audit
ORDER BY created_at DESC, transmission_order NULLS LAST;

-- 4. Transmission success/failure and retry history.
SELECT transmission_id, started_at, satellite_name, station_name,
       queue_label, mode, attempt_number, result, bytes_sent,
       observed_link_quality, failure_reason
FROM transmission_history
ORDER BY started_at DESC;

-- 5. Modes supported simultaneously by a payload and a station.
SELECT p.name AS payload, gs.name AS station, cm.mode
FROM payloads p
JOIN payload_communication_modes pcm ON pcm.payload_id=p.id AND pcm.is_enabled
JOIN communication_modes cm ON cm.id=pcm.communication_mode_id
JOIN station_communication_modes scm ON scm.communication_mode_id=cm.id AND scm.is_enabled
JOIN ground_stations gs ON gs.id=scm.station_id
ORDER BY p.name,gs.name,cm.mode;

-- 6. Deployment event history and confirmation latency.
SELECT s.name AS satellite,d.name AS deployer,e.event_number,
       e.deployment_status,e.confirmation_method,
       e.confirmed_at-e.initiated_at AS confirmation_latency
FROM deployment_events e
JOIN satellites s ON s.id=e.satellite_id
JOIN deployers d ON d.id=e.deployer_id
ORDER BY e.event_number DESC;

-- 7. Mission-level performance aggregate.
SELECT * FROM mission_performance ORDER BY satellite_id;

-- 8. Dataset summary - useful for demonstrating table cardinality.
SELECT 'telemetry' AS entity,count(*) AS rows FROM telemetry
UNION ALL SELECT 'ground_passes',count(*) FROM ground_passes
UNION ALL SELECT 'data_queue',count(*) FROM data_queue
UNION ALL SELECT 'routing_decisions',count(*) FROM routing_decisions
UNION ALL SELECT 'routing_decision_items',count(*) FROM routing_decision_items
UNION ALL SELECT 'transmission_logs',count(*) FROM transmission_logs
UNION ALL SELECT 'commands',count(*) FROM commands
ORDER BY entity;

-- 9. Communication-mode performance comparison.
SELECT mode,count(*) AS attempts,
       count(*) FILTER(WHERE result='SUCCESS') AS successes,
       round(100.0*count(*) FILTER(WHERE result='SUCCESS')/count(*),2) AS success_rate_pct,
       round(avg(observed_link_quality),2) AS avg_link_quality
FROM transmission_logs GROUP BY mode ORDER BY success_rate_pct DESC;

-- 10. Battery and link-quality trend grouped into six-hour windows.
SELECT date_trunc('day',recorded_at)+(extract(hour FROM recorded_at)::int/6)*interval '6 hours' AS window_start,
       round(avg(battery_percent),2) AS avg_battery,
       round(avg(link_quality),2) AS avg_link_quality,
       round(max(temperature_c),2) AS peak_temperature
FROM telemetry GROUP BY window_start ORDER BY window_start;

-- 11. Example parameterized inserts for application CRUD.
-- Use parameters in the backend; do not concatenate user input.
PREPARE add_ground_station(text,text,text,numeric,numeric) AS
INSERT INTO ground_stations(code,name,city,latitude,longitude)
VALUES($1,$2,$3,$4,$5)
RETURNING *;

PREPARE enqueue_packet(bigint,communication_mode,text,text,integer,smallint,smallint,timestamptz) AS
INSERT INTO data_queue(satellite_id,mode,label,payload_type,size_kb,urgency,priority_score,deadline_at,status)
VALUES($1,$2,$3,$4,$5,$6,$7,$8,'QUEUED')
RETURNING *;

PREPARE record_telemetry(bigint,numeric,numeric,smallint,numeric,numeric,numeric,numeric) AS
INSERT INTO telemetry(satellite_id,battery_percent,temperature_c,link_quality,storage_percent,power_draw_w,rssi_dbm,snr_db)
VALUES($1,$2,$3,$4,$5,$6,$7,$8)
RETURNING *;
