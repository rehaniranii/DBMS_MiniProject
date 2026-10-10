BEGIN;
INSERT INTO satellites(name,norad_id,operational_state,orbit_number,uptime_label,launched_at) VALUES ('SomaiyaSat-1','PENDING','NOMINAL',1847,'127d 08h',now()-interval '127 days');
INSERT INTO deployers(satellite_id,name,release_mechanism,state,separation_confirmed,separation_confirmed_at) VALUES (1,'SomaiyaPod-1','Burn-wire + spring pusher','DEPLOYED',true,now()-interval '127 days');
INSERT INTO deployment_events(deployer_id,satellite_id,event_number,scheduled_at,initiated_at,confirmed_at,deployment_status,confirmation_status,confirmation_method,notes) VALUES
(1,1,1,now()-interval '127 days 10 minutes',now()-interval '127 days',now()-interval '127 days'+interval '5 seconds','CONFIRMED','RECEIVED','Separation switch + RF beacon','Simulated academic mission event.');
INSERT INTO communication_modes(mode,bitrate_bps,power_cost_w,description) VALUES
('TT&C',1200,0.42,'Telemetry, tracking, command and housekeeping channel'),('Codec2',2400,0.58,'Low-bitrate resilient digital voice'),('M17',4800,0.68,'Open digital voice and data protocol'),('SSTV',9600,0.86,'Slow-scan television image downlink');
INSERT INTO payloads(satellite_id,name,payload_type,status,power_rating_w,description) VALUES
(1,'TT&C and Housekeeping Unit','TT&C_HOUSEKEEPING','ACTIVE',0.150,'Critical telemetry and command module'),
(1,'Multi-mode Digital Voice Unit','DIGITAL_VOICE','ACTIVE',0.220,'Shared Codec2 and M17 voice payload'),
(1,'SSTV Imaging Unit','SSTV_IMAGING','ACTIVE',0.250,'Camera and SSTV encoder payload');
INSERT INTO payload_communication_modes(payload_id,communication_mode_id,is_enabled) VALUES
(1,1,true),(2,2,true),(2,3,true),(3,4,true);
INSERT INTO ground_stations(code,name,city,latitude,longitude,status,signal_percent,elevation_deg,next_pass_label) VALUES
('IN-MUM','Somaiya Ground','Mumbai, IN',19.076,72.8777,'TRACKING',86,42,'Live · 07:18 left'),
('FI-HEL','ReOrbit North','Helsinki, FI',60.1699,24.9384,'READY',0,0,'12:44 UTC'),
('JP-TOK','HAM Tokyo','Tokyo, JP',35.6762,139.6503,'READY',0,0,'14:09 UTC'),
('IN-PUN','Pune HAM Ground','Pune, IN',18.5204,73.8567,'READY',0,0,'15:26 UTC'),
('IN-BLR','Bengaluru Space Lab','Bengaluru, IN',12.9716,77.5946,'READY',0,0,'16:48 UTC'),
('IN-DEL','Delhi Amateur Radio','New Delhi, IN',28.6139,77.2090,'MAINTENANCE',0,0,'Maintenance'),
('NO-TRO','Tromsø Arctic Ground','Tromsø, NO',69.6492,18.9553,'READY',0,0,'18:02 UTC'),
('AU-SYD','Sydney HAM Network','Sydney, AU',-33.8688,151.2093,'READY',0,0,'21:37 UTC');
INSERT INTO station_communication_modes(station_id,communication_mode_id,is_enabled)
SELECT s.station_id,m.mode_id,true
FROM generate_series(1,8) AS s(station_id)
CROSS JOIN generate_series(1,4) AS m(mode_id);
INSERT INTO telemetry(satellite_id,battery_percent,temperature_c,link_quality,storage_percent,power_draw_w,rssi_dbm,snr_db) VALUES
(1,74.8,23.9,72,44,0.76,-91,7.8),(1,76.2,24.2,79,43,0.74,-87,9.6),(1,78,24.6,86,41,0.72,-82,11.4);
-- Four days of 30-minute housekeeping history (192 additional samples).
INSERT INTO telemetry(satellite_id,battery_percent,temperature_c,link_quality,storage_percent,power_draw_w,rssi_dbm,snr_db,recorded_at)
SELECT 1,
  round((62 + 22*sin(g/7.0) + (g%5))::numeric,2),
  round((19 + 8*sin(g/11.0) + (g%3)*0.35)::numeric,2),
  greatest(18,least(96,round(55 + 34*sin(g/5.0))))::smallint,
  round((28 + (g%58)*0.52)::numeric,2),
  round((0.48 + (g%9)*0.047)::numeric,3),
  round((-112 + 29*abs(sin(g/5.0)))::numeric,2),
  round((-2 + 15*abs(sin(g/5.0)))::numeric,2),
  now()-interval '4 days'+g*interval '30 minutes'
FROM generate_series(0,191) AS sample(g);
INSERT INTO ground_passes(satellite_id,station_id,aos_at,los_at,max_elevation_deg,status) VALUES
(1,1,now()-interval '5 minutes',now()+interval '8 minutes',64,'ACTIVE'),(1,2,now()+interval '2 hours',now()+interval '2 hours 11 minutes',38,'SCHEDULED');
-- Historical and upcoming passes distributed across the station network.
INSERT INTO ground_passes(satellite_id,station_id,aos_at,los_at,max_elevation_deg,status)
SELECT 1,1+(g%8),
  now()-interval '3 days'+g*interval '3 hours 17 minutes',
  now()-interval '3 days'+g*interval '3 hours 17 minutes'+(8+(g%7))*interval '1 minute',
  (18+(g*13)%67)::numeric,
  CASE WHEN g<21 THEN 'COMPLETED'::pass_status ELSE 'SCHEDULED'::pass_status END
FROM generate_series(0,31) AS pass(g);
INSERT INTO data_queue(satellite_id,mode,label,payload_type,size_kb,urgency,priority_score,deadline_at,deadline_label,status) VALUES
(1,'TT&C','Health beacon #1847','HOUSEKEEPING',18,100,100,now()+interval '2 minutes','Immediate','TRANSMITTING'),
(1,'SSTV','Western Ghats frame','IMAGE',640,70,76,now()+interval '3 hours','Next 2 passes','QUEUED'),
(1,'Codec2','HAM voice packet 05','VOICE',92,56,54,now()+interval '18 minutes','18 min','QUEUED'),
(1,'M17','Digital relay bundle','DATA',124,35,42,NULL,'Best effort','QUEUED');
-- Additional realistic mission traffic covering every communication mode and status.
INSERT INTO data_queue(satellite_id,mode,label,payload_type,size_kb,urgency,priority_score,deadline_at,deadline_label,status,created_at)
SELECT 1,
  (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
  CASE g%4 WHEN 0 THEN 'Housekeeping frame #'||to_char(1847+g,'FM0000')
           WHEN 1 THEN 'Earth observation image '||to_char(g,'FM00')
           WHEN 2 THEN 'Codec2 voice message '||to_char(g,'FM00')
           ELSE 'M17 digital relay '||to_char(g,'FM00') END,
  CASE g%4 WHEN 0 THEN 'HOUSEKEEPING' WHEN 1 THEN 'IMAGE' WHEN 2 THEN 'VOICE' ELSE 'DATA' END,
  CASE g%4 WHEN 0 THEN 16+(g%6) WHEN 1 THEN 420+(g*17)%360 WHEN 2 THEN 64+(g*9)%90 ELSE 90+(g*11)%150 END,
  CASE g%4 WHEN 0 THEN 92 WHEN 1 THEN 68 WHEN 2 THEN 51 ELSE 38 END,
  CASE g%4 WHEN 0 THEN 96 WHEN 1 THEN 74 WHEN 2 THEN 55 ELSE 43 END,
  now()+((g%10)+1)*interval '45 minutes',
  ((g%10)+1)||' pass windows',
  CASE WHEN g<14 THEN 'DELIVERED'::queue_status WHEN g IN (14,19,27) THEN 'FAILED'::queue_status
       WHEN g IN (15,20) THEN 'TRANSMITTING'::queue_status ELSE 'QUEUED'::queue_status END,
  now()-interval '36 hours'+g*interval '48 minutes'
FROM generate_series(0,39) AS packet(g);
INSERT INTO routing_decisions(satellite_id,pass_id,queue_item_id,selected_mode,confidence,score,battery_snapshot,link_snapshot,reason,policy_version) VALUES
(1,1,1,'TT&C',94,91,78,86,'Critical housekeeping is due; link margin and battery reserve are sufficient.','router-dt-1.2');
INSERT INTO routing_decisions(satellite_id,pass_id,queue_item_id,selected_mode,confidence,score,battery_snapshot,link_snapshot,reason,policy_version,overridden,created_at)
SELECT 1,3+(g%20),5+g,
  (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
  74+(g*7)%24,68+(g*11)%29,round((64+(g*3)%27)::numeric,2),(42+(g*9)%54)::smallint,
  CASE g%4 WHEN 0 THEN 'Housekeeping deadline and safety policy produced the highest utility score.'
           WHEN 1 THEN 'High link margin and available energy permit the queued SSTV image.'
           WHEN 2 THEN 'Codec2 provides the best resilience for the current moderate link.'
           ELSE 'M17 traffic selected after all higher-priority packets cleared.' END,
  CASE WHEN g<12 THEN 'router-dt-1.1' ELSE 'router-dt-1.2' END,
  g IN (9,23),now()-interval '30 hours'+g*interval '57 minutes'
FROM generate_series(0,27) AS decision(g);
INSERT INTO routing_decision_items(routing_decision_id,queue_item_id,selected_mode,transmission_order,priority_score,action,reason) VALUES
(1,1,'TT&C',1,98,'TRANSMIT','Critical housekeeping always receives the first transmission slot.'),
(1,2,'SSTV',2,76,'TRANSMIT','Current link margin can support the queued image after housekeeping.'),
(1,3,NULL,NULL,54,'DEFER','Codec2 voice can wait for the next pass without missing its deadline.'),
(1,4,NULL,NULL,42,'DEFER','Best-effort M17 traffic is held for surplus contact time.');
INSERT INTO routing_decision_items(routing_decision_id,queue_item_id,selected_mode,transmission_order,priority_score,action,reason)
SELECT 2+g,5+g,
  CASE WHEN g%6 IN (4,5) THEN NULL ELSE (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)] END,
  CASE WHEN g%6 IN (4,5) THEN NULL ELSE 1 END,
  45+(g*9)%53,
  CASE WHEN g%6=4 THEN 'DEFER' WHEN g%6=5 THEN 'REJECT' ELSE 'TRANSMIT' END,
  CASE WHEN g%6=4 THEN 'Deferred to protect the critical power reserve.' WHEN g%6=5 THEN 'Rejected because its deadline expired before contact.' ELSE 'Scheduled within the available pass and power budget.' END
FROM generate_series(0,27) AS item(g);
INSERT INTO transmission_logs(satellite_id,station_id,queue_item_id,mode,bytes_sent,packets_sent,packets_lost,attempt_number,result,observed_link_quality,failure_reason,started_at,ended_at) VALUES
(1,1,1,'TT&C',14320,1284,10,1,'SUCCESS',86,NULL,now()-interval '5 minutes',now()-interval '4 minutes'),
(1,1,2,'SSTV',0,42,42,1,'FAILED',31,'Link quality dropped below the safe SSTV threshold.',now()-interval '3 minutes',now()-interval '2 minutes'),
(1,1,2,'SSTV',655360,960,8,2,'SUCCESS',82,NULL,now()-interval '90 seconds',now()-interval '20 seconds');
INSERT INTO transmission_logs(satellite_id,station_id,queue_item_id,mode,bytes_sent,packets_sent,packets_lost,attempt_number,result,observed_link_quality,failure_reason,started_at,ended_at)
SELECT 1,1+(g%8),5+g,
  (ARRAY['TT&C'::communication_mode,'SSTV'::communication_mode,'Codec2'::communication_mode,'M17'::communication_mode])[1+(g%4)],
  CASE WHEN g%9 IN (3,7) THEN 0 ELSE (16000+(g*13700)%720000) END,
  90+(g*37)%900,
  CASE WHEN g%9 IN (3,7) THEN 90+(g*37)%900 ELSE (g*3)%18 END,
  1,
  CASE WHEN g%9 IN (3,7) THEN 'FAILED' WHEN g%9=5 THEN 'PARTIAL' ELSE 'SUCCESS' END,
  30+(g*13)%67,
  CASE WHEN g%9 IN (3,7) THEN 'Contact lost below the minimum link threshold.' WHEN g%9=5 THEN 'Pass ended before the packet completed.' ELSE NULL END,
  now()-interval '34 hours'+g*interval '63 minutes',
  now()-interval '34 hours'+g*interval '63 minutes'+(25+(g%50))*interval '1 second'
FROM generate_series(0,27) AS transmission(g);
INSERT INTO commands(satellite_id,station_id,command_type,payload,status,issued_by,issued_at,acknowledged_at) VALUES
(1,1,'REQUEST_TELEMETRY','{"scope":"housekeeping","priority":"critical"}','ACKNOWLEDGED','operator@somaiyasat.in',now()-interval '8 minutes',now()-interval '7 minutes'),
(1,1,'MODE_SWITCH','{"target_mode":"M17","condition":"link_quality > 70"}','PENDING','operator@somaiyasat.in',now()-interval '2 minutes',NULL);
INSERT INTO commands(satellite_id,station_id,command_type,payload,status,issued_by,issued_at,acknowledged_at)
SELECT 1,1+(g%8),
  (ARRAY['REQUEST_TELEMETRY','MODE_SWITCH','ROUTING_OVERRIDE','SAFE_MODE'])[1+(g%4)],
  jsonb_build_object('sequence',g+100,'requested_mode',(ARRAY['TT&C','SSTV','Codec2','M17'])[1+(g%4)]),
  CASE WHEN g%5=0 THEN 'PENDING' WHEN g%7=0 THEN 'FAILED' ELSE 'ACKNOWLEDGED' END,
  CASE WHEN g%3=0 THEN 'operator@somaiyasat.in' ELSE 'analyst@somaiyasat.in' END,
  now()-interval '28 hours'+g*interval '79 minutes',
  CASE WHEN g%5=0 OR g%7=0 THEN NULL ELSE now()-interval '28 hours'+g*interval '79 minutes'+interval '8 seconds' END
FROM generate_series(0,23) AS command(g);
COMMIT;
