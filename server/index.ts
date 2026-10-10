import express from 'express'
import cors from 'cors'
import { z } from 'zod'
import { dashboard } from './demo.js'
import { query } from './db.js'

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
app.post('/api/stations',async(req,res)=>{const parsed=stationSchema.safeParse(req.body);if(!parsed.success)return res.status(400).json({error:parsed.error.flatten()});if(demo){const station={id:Date.now(),...parsed.data,signal:0,elevation:0,nextPass:'Calculating…'};dashboard.stations.push(station);return res.status(201).json(station)};const r=await query('INSERT INTO ground_stations(code,name,city,status) VALUES($1,$2,$3,$4) RETURNING *',[parsed.data.code,parsed.data.name,parsed.data.city,parsed.data.status]);res.status(201).json(r.rows[0])})
app.put('/api/stations/:id',async(req,res)=>{const parsed=stationSchema.partial().safeParse(req.body);if(!parsed.success)return res.status(400).json({error:parsed.error.flatten()});if(demo){const s=dashboard.stations.find(x=>x.id===Number(req.params.id));if(!s)return res.sendStatus(404);Object.assign(s,parsed.data);return res.json(s)};const r=await query('UPDATE ground_stations SET name=COALESCE($1,name),city=COALESCE($2,city),status=COALESCE($3,status),updated_at=now() WHERE id=$4 RETURNING *',[parsed.data.name,parsed.data.city,parsed.data.status,req.params.id]);res.json(r.rows[0])})
app.delete('/api/stations/:id',async(req,res)=>{if(demo){const i=dashboard.stations.findIndex(x=>x.id===Number(req.params.id));if(i<0)return res.sendStatus(404);dashboard.stations.splice(i,1);return res.sendStatus(204)};await query('DELETE FROM ground_stations WHERE id=$1',[req.params.id]);res.sendStatus(204)})
app.post('/api/routing/simulate',(req,res)=>{const battery=Number(req.body.battery||0),link=Number(req.body.linkQuality||0);const selectedMode=battery<25?'TT&C':link>75?'SSTV':'Codec2';const reason=battery<25?'Battery reserve is constrained; fail-safe policy allows critical housekeeping only.':link>75?'Link margin supports the queued SSTV frame without risking the TT&C reserve.':'Moderate link quality favors the resilient low-bitrate Codec2 channel.';const decision={id:Date.now(),selectedMode,confidence:Math.min(97,72+Math.round(link/5)),score:Math.round((battery*.35)+(link*.65)),reason,createdAt:new Date().toISOString().slice(11,19)+' UTC'};dashboard.decisions.unshift(decision as typeof dashboard.decisions[number]);res.status(201).json(decision)})
app.use(express.static('dist'));app.get('*path',(_req,res)=>res.sendFile('index.html',{root:'dist'}))
app.listen(port,()=>console.log(`SomaiyaSat API listening on http://localhost:${port}`))
