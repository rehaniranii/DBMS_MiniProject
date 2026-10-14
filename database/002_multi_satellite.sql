BEGIN;

INSERT INTO satellites(name,norad_id,operational_state,orbit_number,uptime_label,launched_at) VALUES
('SomaiyaSat-2','PENDING','COMMISSIONING',426,'28d 14h',now()-interval '28 days 14 hours'),
('KJS Cube-1','99001','NOMINAL',963,'67d 02h',now()-interval '67 days 2 hours')
ON CONFLICT (name) DO UPDATE SET
  norad_id=EXCLUDED.norad_id, operational_state=EXCLUDED.operational_state,
  orbit_number=EXCLUDED.orbit_number, uptime_label=EXCLUDED.uptime_label;

DO $$
DECLARE sat RECORD; sat_index INTEGER;
BEGIN
  FOR sat IN SELECT id,name FROM satellites WHERE name IN ('SomaiyaSat-2','KJS Cube-1') ORDER BY id LOOP
    sat_index := CASE WHEN sat.name='SomaiyaSat-2' THEN 2 ELSE 3 END;

    IF NOT EXISTS (SELECT 1 FROM deployers WHERE satellite_id=sat.id) THEN
      INSERT INTO deployers(satellite_id,name,release_mechanism,state,separation_confirmed,separation_confirmed_at)
      VALUES(sat.id,'SomaiyaPod-'||sat_index,'Burn-wire + spring pusher','DEPLOYED',true,
        now()-(CASE WHEN sat_index=2 THEN interval '28 days' ELSE interval '67 days' END));
    END IF;

    INSERT INTO payloads(satellite_id,name,payload_type,status,power_rating_w,description) VALUES
      (sat.id,sat.name||' Housekeeping','TT&C_HOUSEKEEPING','ACTIVE',0.155,'Command, telemetry, and spacecraft health payload'),
      (sat.id,sat.name||' Multi-mode Radio','MULTI_MODE','ACTIVE',0.235,'SSTV, Codec2, and M17 experimental transceiver')
    ON CONFLICT (satellite_id,name) DO NOTHING;

    IF NOT EXISTS (SELECT 1 FROM telemetry WHERE satellite_id=sat.id) THEN
      INSERT INTO telemetry(satellite_id,battery_percent,temperature_c,link_quality,storage_percent,power_draw_w,rssi_dbm,snr_db,recorded_at)
      SELECT sat.id,
        round(((CASE sat_index WHEN 2 THEN 72 ELSE 61 END)+14*sin(g/6.0)+(g%4))::numeric,2),
        round(((CASE sat_index WHEN 2 THEN 21 ELSE 18 END)+6*sin(g/9.0)+(g%3)*0.3)::numeric,2),
        greatest(22,least(96,round((CASE sat_index WHEN 2 THEN 58 ELSE 64 END)+27*sin(g/5.0))))::smallint,
        round((24+(g%38)*0.83)::numeric,2),round((0.49+(g%8)*0.052)::numeric,2),
        round((-108+26*abs(sin(g/5.0)))::numeric,2),round((-1+14*abs(sin(g/5.0)))::numeric,2),
        now()-interval '24 hours'+g*interval '30 minutes'
      FROM generate_series(0,47) AS sample(g);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM data_queue WHERE satellite_id=sat.id) THEN
      INSERT INTO data_queue(satellite_id,mode,label,payload_type,size_kb,urgency,priority_score,deadline_at,deadline_label,status,created_at)
      SELECT sat.id,
        (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
        CASE g%4 WHEN 0 THEN sat.name||' health beacon #'||(400+g)
          WHEN 1 THEN sat.name||' orbital image '||to_char(g,'FM00')
          WHEN 2 THEN sat.name||' voice packet '||to_char(g,'FM00')
          ELSE sat.name||' digital relay '||to_char(g,'FM00') END,
        CASE g%4 WHEN 0 THEN 'HOUSEKEEPING' WHEN 1 THEN 'IMAGE' WHEN 2 THEN 'VOICE' ELSE 'DATA' END,
        CASE g%4 WHEN 0 THEN 18+(g%5) WHEN 1 THEN 380+(g*31)%420 WHEN 2 THEN 72+(g*7)%90 ELSE 96+(g*13)%180 END,
        35+(g*11)%65,42+(g*9)%58,now()+((g%8)+1)*interval '50 minutes',((g%8)+1)||' pass windows',
        CASE WHEN g<3 THEN 'DELIVERED'::queue_status WHEN g=3 THEN 'TRANSMITTING'::queue_status ELSE 'QUEUED'::queue_status END,
        now()-interval '12 hours'+g*interval '47 minutes'
      FROM generate_series(0,14) AS packet(g);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ground_passes WHERE satellite_id=sat.id) THEN
      INSERT INTO ground_passes(satellite_id,station_id,aos_at,los_at,max_elevation_deg,status)
      SELECT sat.id,1+(g%8),now()+g*interval '96 minutes',now()+g*interval '96 minutes'+(8+(g%6))*interval '1 minute',
        20+(g*11)%66,'SCHEDULED'::pass_status FROM generate_series(1,12) AS pass(g);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM routing_decisions WHERE satellite_id=sat.id) THEN
      INSERT INTO routing_decisions(satellite_id,selected_mode,confidence,score,battery_snapshot,link_snapshot,reason,policy_version,created_at)
      SELECT sat.id,
        (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
        73+(g*7)%25,65+(g*9)%32,68+(g*3)%24,40+(g*8)%55,
        CASE g%4 WHEN 0 THEN 'Safety and housekeeping urgency produced the highest utility score.'
          WHEN 1 THEN 'Energy reserve and link margin permit the queued image downlink.'
          WHEN 2 THEN 'Codec2 maximizes resilience under the current moderate link.'
          ELSE 'M17 balances throughput and power after critical traffic cleared.' END,
        'router-dt-1.3',now()-interval '10 hours'+g*interval '61 minutes'
      FROM generate_series(0,9) AS decision(g);
    END IF;
  END LOOP;
END $$;

COMMIT;
