import express from 'express'
import cors from 'cors'
import { z } from 'zod'
import { dashboard } from './demo.js'
import { query } from './db.js'

// Runtime mode is selected through .env so demo and PostgreSQL setups share one API.
const app=express(); const port=Number(process.env.PORT||4000); const demo=process.env.USE_DEMO_DATA!=='false'
app.use(cors());app.use(express.json())
app.get('/api/health',(_req,res)=>res.json({ok:true,database:demo?'demo':'postgresql'}))
app.get('/api/dashboard',async(_req,res)=>{
  if(demo)return res.json(dashboard)
  try{
    const [sat,telemetry,stations,queue,decisions]=await Promise.all([
      query('SELECT name, norad_id AS norad, operational_state AS state, orbit_number AS orbit, uptime_label AS uptime FROM satellites ORDER BY id LIMIT 1'),
      query('SELECT battery_percent AS battery, temperature_c AS temperature, link_quality AS "linkQuality", storage_percent AS storage, power_draw_w AS "powerDraw" FROM telemetry ORDER BY recorded_at DESC LIMIT 1'),
      query(`SELECT id, code, name, city, status, signal_percent AS signal, elevation_deg AS elevation, next_pass_label AS "nextPass" FROM ground_stations ORDER BY id`),
      query(`SELECT id, mode::text AS type, label, size_kb AS "sizeKb", priority_score AS priority, deadline_label AS deadline, status FROM data_queue WHERE status <> 'DELIVERED' ORDER BY priority_score DESC`),
      query(`SELECT id, selected_mode::text AS "selectedMode", confidence, score, reason, to_char(created_at,'HH24:MI:SS UTC') AS "createdAt" FROM routing_decisions ORDER BY created_at DESC LIMIT 10`),
    ])
    res.json({satellite:sat.rows[0],telemetry:telemetry.rows[0],deployment:dashboard.deployment,stations:stations.rows,queue:queue.rows,decisions:decisions.rows})
  }catch(e){res.status(500).json({error:'Database query failed',detail:e instanceof Error?e.message:'Unknown error'})}
})
const stationSchema=z.object({code:z.string().min(2),name:z.string().min(2),city:z.string().default('Unknown'),status:z.string().default('READY')})
app.get('/api/stations',async(_req,res)=>{if(demo)return res.json(dashboard.stations);const r=await query('SELECT * FROM ground_stations ORDER BY id');res.json(r.rows)})
const explorerQueries:Record<string,{title:string;columns:string[];sql:string}>={
  queue:{title:'Mission data queue',columns:['ID','PAYLOAD','MODE','SIZE','PRIORITY','STATUS'],sql:`SELECT id::text AS "ID",label AS "PAYLOAD",mode::text AS "MODE",size_kb||' KB' AS "SIZE",priority_score::text AS "PRIORITY",status::text AS "STATUS" FROM data_queue ORDER BY created_at DESC`},
  decisions:{title:'AI routing decisions',columns:['ID','DECIDED AT','MODE','CONFIDENCE','SCORE','POLICY'],sql:`SELECT id::text AS "ID",to_char(created_at,'DD Mon HH24:MI') AS "DECIDED AT",selected_mode::text AS "MODE",confidence||'%' AS "CONFIDENCE",score::text AS "SCORE",policy_version AS "POLICY" FROM routing_decisions ORDER BY created_at DESC`},
  stations:{title:'Ground station directory',columns:['ID','STATION','CODE','LOCATION','STATUS','NEXT PASS'],sql:`SELECT id::text AS "ID",name AS "STATION",code AS "CODE",city AS "LOCATION",status AS "STATUS",next_pass_label AS "NEXT PASS" FROM ground_stations ORDER BY id`},
  telemetry:{title:'Telemetry history',columns:['ID','RECORDED AT','BATTERY','TEMP','LINK','POWER'],sql:`SELECT id::text AS "ID",to_char(recorded_at,'DD Mon HH24:MI') AS "RECORDED AT",battery_percent||'%' AS "BATTERY",temperature_c||'°C' AS "TEMP",link_quality||'%' AS "LINK",power_draw_w||' W' AS "POWER" FROM telemetry ORDER BY recorded_at DESC LIMIT 250`},
}
app.get('/api/explorer/:entity',async(req,res)=>{
  const config=explorerQueries[req.params.entity];if(!config)return res.status(404).json({error:'Unknown explorer entity'})
  if(demo){
    const rows=req.params.entity==='queue'?dashboard.queue.map(q=>({ID:String(q.id),PAYLOAD:q.label,MODE:q.type,SIZE:`${q.sizeKb} KB`,PRIORITY:String(q.priority),STATUS:q.status})):
      req.params.entity==='decisions'?dashboard.decisions.map(d=>({ID:String(d.id),'DECIDED AT':d.createdAt,MODE:d.selectedMode,CONFIDENCE:`${d.confidence}%`,SCORE:String(d.score),POLICY:'router-dt-1.2'})):
      req.params.entity==='stations'?dashboard.stations.map(s=>({ID:String(s.id),STATION:s.name,CODE:s.code,LOCATION:s.city,STATUS:s.status,'NEXT PASS':s.nextPass})):
      Array.from({length:24},(_,i)=>({ID:String(i+1),'RECORDED AT':`${i*5} min ago`,BATTERY:`${78-i%7}%`,TEMP:`${(24.6+i%4*.3).toFixed(1)}°C`,LINK:`${86-i%12}%`,POWER:`${(0.72+i%5*.02).toFixed(2)} W`}))
    return res.json({entity:req.params.entity,title:config.title,columns:config.columns,rows,total:rows.length})
  }
  try{const result=await query(config.sql);res.json({entity:req.params.entity,title:config.title,columns:config.columns,rows:result.rows,total:result.rowCount})}
  catch(e){res.status(500).json({error:'Explorer query failed',detail:e instanceof Error?e.message:'Unknown error'})}
})
app.post('/api/stations',async(req,res)=>{const parsed=stationSchema.safeParse(req.body);if(!parsed.success)return res.status(400).json({error:parsed.error.flatten()});if(demo){const station={id:Date.now(),...parsed.data,signal:0,elevation:0,nextPass:'Calculating…'};dashboard.stations.push(station);return res.status(201).json(station)};const r=await query('INSERT INTO ground_stations(code,name,city,status) VALUES($1,$2,$3,$4) RETURNING *',[parsed.data.code,parsed.data.name,parsed.data.city,parsed.data.status]);res.status(201).json(r.rows[0])})
app.put('/api/stations/:id',async(req,res)=>{const parsed=stationSchema.partial().safeParse(req.body);if(!parsed.success)return res.status(400).json({error:parsed.error.flatten()});if(demo){const s=dashboard.stations.find(x=>x.id===Number(req.params.id));if(!s)return res.sendStatus(404);Object.assign(s,parsed.data);return res.json(s)};const r=await query('UPDATE ground_stations SET name=COALESCE($1,name),city=COALESCE($2,city),status=COALESCE($3,status),updated_at=now() WHERE id=$4 RETURNING *',[parsed.data.name,parsed.data.city,parsed.data.status,req.params.id]);res.json(r.rows[0])})
app.delete('/api/stations/:id',async(req,res)=>{if(demo){const i=dashboard.stations.findIndex(x=>x.id===Number(req.params.id));if(i<0)return res.sendStatus(404);dashboard.stations.splice(i,1);return res.sendStatus(204)};await query('DELETE FROM ground_stations WHERE id=$1',[req.params.id]);res.sendStatus(204)})
app.post('/api/routing/simulate',async(req,res)=>{
  const battery=Math.max(0,Math.min(100,Number(req.body.battery??0)))
  const link=Math.max(0,Math.min(100,Number(req.body.linkQuality??0)))
  const urgency=Math.max(0,Math.min(100,Number(req.body.urgency??50)))
  let selectedMode:'TT&C'|'SSTV'|'Codec2'|'M17'
  let reason:string
  if(battery<25){selectedMode='TT&C';reason='Battery reserve is constrained; the fail-safe policy protects spacecraft power with the lowest-cost channel.'}
  else if(urgency>=80){selectedMode='TT&C';reason='Critical data urgency takes priority over throughput, selecting the most dependable command and telemetry channel.'}
  else if(link>=75&&battery>=55){selectedMode='SSTV';reason='Strong link margin and healthy battery reserve support the queued high-throughput image downlink.'}
  else if(link>=55&&urgency<45){selectedMode='M17';reason='Stable link conditions and low urgency make M17 the most efficient balanced route.'}
  else if(link>=35){selectedMode='Codec2';reason='Moderate link quality favors the resilient low-bitrate Codec2 channel.'}
  else {selectedMode='TT&C';reason='Weak link quality triggers the robust TT&C fallback to maximize delivery probability.'}
  const score=Math.round(battery*.3+link*.45+urgency*.25)
  const confidence=Math.min(98,Math.max(68,72+Math.round(Math.abs(link-50)/4)+Math.round(Math.abs(battery-25)/12)))
  const createdAt=new Date().toISOString().slice(11,19)+' UTC'
  if(demo){
    const decision={id:Date.now(),selectedMode,confidence,score,reason,createdAt}
    dashboard.decisions.unshift(decision as typeof dashboard.decisions[number])
    return res.status(201).json(decision)
  }
  try{
    const result=await query(`INSERT INTO routing_decisions
      (satellite_id,selected_mode,confidence,score,battery_snapshot,link_snapshot,reason,policy_version)
      VALUES ((SELECT id FROM satellites ORDER BY id LIMIT 1),$1,$2,$3,$4,$5,$6,'router-lab-1.3')
      RETURNING id,selected_mode::text AS "selectedMode",confidence,score,reason,to_char(created_at,'HH24:MI:SS UTC') AS "createdAt"`,
      [selectedMode,confidence,score,battery,link,reason])
    res.status(201).json(result.rows[0])
  }catch(e){res.status(500).json({error:'Routing simulation failed',detail:e instanceof Error?e.message:'Unknown error'})}
})
if(!process.env.VERCEL){
  app.use(express.static('dist'));app.get('*path',(_req,res)=>res.sendFile('index.html',{root:'dist'}))
  app.listen(port,()=>console.log(`SomaiyaSat API listening on http://localhost:${port}`))
}

export default app
