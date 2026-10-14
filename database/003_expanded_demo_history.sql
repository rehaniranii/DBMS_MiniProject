BEGIN;

-- A larger, repeat-safe academic dataset for every tracked spacecraft.
DO $$
DECLARE sat RECORD;
BEGIN
  FOR sat IN SELECT id,name FROM satellites ORDER BY id LOOP
    IF NOT EXISTS (
      SELECT 1 FROM telemetry
      WHERE satellite_id=sat.id AND recorded_at < now()-interval '10 days'
    ) THEN
      INSERT INTO telemetry(
        satellite_id,battery_percent,temperature_c,link_quality,storage_percent,
        power_draw_w,rssi_dbm,snr_db,recorded_at
      )
      SELECT sat.id,
        round((58+24*abs(sin((g+sat.id)/9.0))+(g%4))::numeric,2),
        round((17+9*sin((g+sat.id)/13.0)+(g%3)*0.25)::numeric,2),
        greatest(16,least(98,round(48+43*abs(sin((g+sat.id)/7.0))))::smallint),
        round((18+(g%71)*0.91)::numeric,2),
        round((0.44+(g%10)*0.049)::numeric,2),
        round((-116+35*abs(sin((g+sat.id)/7.0)))::numeric,2),
        round((-3+18*abs(sin((g+sat.id)/7.0)))::numeric,2),
        now()-interval '30 days'+g*interval '3 hours'
      FROM generate_series(0,239) AS samples(g);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM data_queue WHERE satellite_id=sat.id AND label LIKE 'Demo archive %'
    ) THEN
      INSERT INTO data_queue(
        satellite_id,mode,label,payload_type,size_kb,urgency,priority_score,
        deadline_at,deadline_label,status,created_at
      )
      SELECT sat.id,
        (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
        'Demo archive '||sat.name||' packet '||to_char(g+1,'FM000'),
        (ARRAY['HOUSEKEEPING','IMAGE','VOICE','DATA'])[1+(g%4)],
        CASE g%4 WHEN 0 THEN 12+(g%12) WHEN 1 THEN 360+(g*29)%690 WHEN 2 THEN 52+(g*11)%170 ELSE 80+(g*17)%310 END,
        22+(g*13)%79,30+(g*17)%71,
        now()-interval '20 days'+g*interval '9 hours',
        CASE WHEN g%5=0 THEN 'Immediate' ELSE ((g%9)+1)||' pass windows' END,
        CASE WHEN g<38 THEN 'DELIVERED'::queue_status
             WHEN g IN (41,53) THEN 'FAILED'::queue_status
             WHEN g IN (42,54) THEN 'EXPIRED'::queue_status
             WHEN g IN (43,55) THEN 'TRANSMITTING'::queue_status
             ELSE 'QUEUED'::queue_status END,
        now()-interval '25 days'+g*interval '8 hours'
      FROM generate_series(0,59) AS packets(g);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM routing_decisions WHERE satellite_id=sat.id AND policy_version='router-demo-2.0'
    ) THEN
      INSERT INTO routing_decisions(
        satellite_id,selected_mode,confidence,score,battery_snapshot,link_snapshot,
        reason,policy_version,overridden,created_at
      )
      SELECT sat.id,
        (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
        70+(g*11)%29,61+(g*13)%38,round((57+(g*5)%39)::numeric,2),(28+(g*9)%69)::smallint,
        CASE g%4
          WHEN 0 THEN 'Housekeeping deadline and safety constraints gave TT&C the highest score.'
          WHEN 1 THEN 'Healthy battery and strong link margin supported the SSTV image downlink.'
          WHEN 2 THEN 'Codec2 offered the best resilience for the measured link quality.'
          ELSE 'M17 balanced throughput, urgency and available spacecraft power.' END,
        'router-demo-2.0',g IN (14,31),now()-interval '20 days'+g*interval '11 hours'
      FROM generate_series(0,39) AS decisions(g);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM ground_passes WHERE satellite_id=sat.id AND aos_at < now()-interval '10 days'
    ) THEN
      INSERT INTO ground_passes(satellite_id,station_id,aos_at,los_at,max_elevation_deg,status)
      SELECT sat.id,1+(g%8),
        now()-interval '24 days'+g*interval '13 hours 17 minutes',
        now()-interval '24 days'+g*interval '13 hours 17 minutes'+(7+(g%8))*interval '1 minute',
        12+(g*17)%77,
        CASE WHEN g<32 THEN 'COMPLETED'::pass_status ELSE 'MISSED'::pass_status END
      FROM generate_series(0,35) AS passes(g);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM commands WHERE satellite_id=sat.id AND issued_by='seedbot@somaiyasat.in'
    ) THEN
      INSERT INTO commands(
        satellite_id,station_id,command_type,payload,status,issued_by,issued_at,acknowledged_at
      )
      SELECT sat.id,1+(g%8),
        (ARRAY['REQUEST_TELEMETRY','MODE_SWITCH','ROUTING_OVERRIDE','PAYLOAD_CHECK'])[1+(g%4)],
        jsonb_build_object('sequence',sat.id*1000+g,'requested_mode',(ARRAY['TT&C','SSTV','Codec2','M17'])[1+(g%4)]),
        CASE WHEN g%8=0 THEN 'PENDING' WHEN g%11=0 THEN 'FAILED' ELSE 'ACKNOWLEDGED' END,
        'seedbot@somaiyasat.in',now()-interval '18 days'+g*interval '12 hours',
        CASE WHEN g%8=0 OR g%11=0 THEN NULL ELSE now()-interval '18 days'+g*interval '12 hours'+interval '9 seconds' END
      FROM generate_series(0,29) AS commands(g);
    END IF;
  END LOOP;
END $$;

-- Transmission history for the generated archive queue rows.
INSERT INTO transmission_logs(
  satellite_id,station_id,queue_item_id,mode,bytes_sent,packets_sent,packets_lost,
  attempt_number,result,observed_link_quality,failure_reason,started_at,ended_at
)
SELECT q.satellite_id,1+(q.rn%8),q.id,q.mode,
  CASE WHEN q.rn%12=5 THEN 0 ELSE q.size_kb*1024 END,
  80+(q.rn*31)%850,
  CASE WHEN q.rn%12=5 THEN 80+(q.rn*31)%850 ELSE (q.rn*3)%19 END,
  1,
  CASE WHEN q.rn%12=5 THEN 'FAILED' WHEN q.rn%9=4 THEN 'PARTIAL' ELSE 'SUCCESS' END,
  27+(q.rn*13)%71,
  CASE WHEN q.rn%12=5 THEN 'Contact dropped below the minimum safe link threshold.'
       WHEN q.rn%9=4 THEN 'Pass ended before the final packet completed.' ELSE NULL END,
  q.created_at+interval '2 hours',q.created_at+interval '2 hours 2 minutes'
FROM (
  SELECT id,satellite_id,mode,size_kb,created_at,
    row_number() OVER(PARTITION BY satellite_id ORDER BY id)::int AS rn
  FROM data_queue WHERE label LIKE 'Demo archive %'
) q
WHERE q.rn<=50
  AND NOT EXISTS (
    SELECT 1 FROM transmission_logs x
    WHERE x.queue_item_id=q.id AND x.station_id=1+(q.rn%8) AND x.attempt_number=1
  );

COMMIT;
