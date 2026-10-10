import { useEffect, useMemo, useState } from 'react'
import { Activity, Antenna, BatteryCharging, Bot, ChevronDown, CircleDot, Clock3, Database, Eye, EyeOff, Gauge, Globe2, LockKeyhole, LogOut, Menu, Orbit, Radio, RefreshCw, Route, Satellite, Search, Server, ShieldCheck, Signal, ThermometerSun, UserRound, X, Zap } from 'lucide-react'
import type { Dashboard, Mode, QueueItem, Station } from './types'

const fallback: Dashboard = {
  satellite: { name: 'SomaiyaSat-1', norad: 'PENDING', state: 'NOMINAL', orbit: 1847, uptime: '127d 08h' },
  telemetry: { battery: 78, temperature: 24.6, linkQuality: 86, storage: 41, powerDraw: 0.72 },
  deployment: { state: 'DEPLOYED', separationConfirmed: true, confirmedAt: '2026-08-06T09:42:18Z' },
  stations: [
    { id: 1, code: 'IN-MUM', name: 'Somaiya Ground', city: 'Mumbai, IN', status: 'TRACKING', signal: 86, elevation: 42, nextPass: 'Live · 07:18 left' },
    { id: 2, code: 'FI-HEL', name: 'ReOrbit North', city: 'Helsinki, FI', status: 'READY', signal: 0, elevation: 0, nextPass: '12:44 UTC' },
    { id: 3, code: 'JP-TOK', name: 'HAM Tokyo', city: 'Tokyo, JP', status: 'READY', signal: 0, elevation: 0, nextPass: '14:09 UTC' },
  ],
  queue: [
    { id: 1, type: 'TT&C', label: 'Health beacon #1847', sizeKb: 18, priority: 100, deadline: 'Immediate', status: 'TRANSMITTING' },
    { id: 2, type: 'SSTV', label: 'Western Ghats frame', sizeKb: 640, priority: 76, deadline: 'Next 2 passes', status: 'QUEUED' },
    { id: 3, type: 'Codec2', label: 'HAM voice packet 05', sizeKb: 92, priority: 54, deadline: '18 min', status: 'QUEUED' },
    { id: 4, type: 'M17', label: 'Digital relay bundle', sizeKb: 124, priority: 42, deadline: 'Best effort', status: 'QUEUED' },
  ],
  decisions: [{ id: 1, selectedMode: 'TT&C', confidence: 94, score: 91, reason: 'Critical housekeeping is due; link margin and battery reserve are sufficient.', createdAt: '10:31:42 UTC' }],
}

const modeClass: Record<Mode, string> = { 'TT&C': 'blue', SSTV: 'violet', Codec2: 'amber', M17: 'mint' }
type Session = { name:string; email:string; role:'operator'|'analyst'|'observer'; label:string }
const demoAccounts = [
  {role:'operator' as const,label:'Mission Operator',name:'Aarav Mehta',email:'operator@somaiyasat.in',password:'Mission@2026',access:'Full mission control · CRUD + commands'},
  {role:'analyst' as const,label:'AI Routing Analyst',name:'Riya Shah',email:'analyst@somaiyasat.in',password:'Router@2026',access:'Routing simulation + data analysis'},
  {role:'observer' as const,label:'HAM Observer',name:'HAM Community',email:'observer@somaiyasat.in',password:'Orbit@2026',access:'Read-only telemetry access'},
]

function LoginScreen({onLogin}:{onLogin:(s:Session)=>void}){
  const [email,setEmail]=useState('');const [password,setPassword]=useState('');const [visible,setVisible]=useState(false);const [error,setError]=useState('');const [busy,setBusy]=useState(false)
  const submit=(e:React.FormEvent)=>{e.preventDefault();setBusy(true);setError('');setTimeout(()=>{const account=demoAccounts.find(a=>a.email===email.trim().toLowerCase()&&a.password===password);if(account){onLogin({name:account.name,email:account.email,role:account.role,label:account.label})}else{setError('Email or password does not match a demo account.');setBusy(false)}},450)}
  const choose=(a:typeof demoAccounts[number])=>{setEmail(a.email);setPassword(a.password);setError('')}
  return <div className="login-page"><div className="login-visual"><div className="login-stars"/><div className="login-brand"><div className="brand-mark"><Orbit/></div><div><strong>SOMAIYA<span>SAT</span></strong><small>AUTONOMOUS MISSION OPERATIONS</small></div></div><div className="login-story"><div className="eyebrow"><span>POCKETQUBE · MISSION CONTROL</span></div><h1>One mission.<br/><em>Every signal.</em></h1><p>Secure access to SomaiyaSat telemetry, autonomous routing, and the global ground-station network.</p><div className="login-orbit"><div className="login-earth"/><div className="login-ring"><Satellite/></div></div></div><div className="login-status"><span><i/>SPACECRAFT NOMINAL</span><span>ORBIT 1847 · LEO</span></div></div><div className="login-panel"><div className="login-form-wrap"><div className="mobile-login-brand"><Orbit/><b>SOMAIYASAT</b></div><small>AUTHORIZED ACCESS</small><h2>Welcome to mission control.</h2><p>Sign in with a mission role to continue.</p><form onSubmit={submit}><label>Email address<div><UserRound/><input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="name@somaiyasat.in" required/></div></label><label>Password<div><LockKeyhole/><input type={visible?'text':'password'} value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter password" required/><button type="button" onClick={()=>setVisible(!visible)} aria-label={visible?'Hide password':'Show password'}>{visible?<EyeOff/>:<Eye/>}</button></div></label>{error&&<div className="login-error">{error}</div>}<button className="login-submit" disabled={busy}>{busy?<><RefreshCw className="spin"/>Authenticating…</>:<>Enter mission control <span>→</span></>}</button></form><div className="demo-divider"><span>DEMO MISSION ACCOUNTS</span></div><div className="demo-accounts">{demoAccounts.map(a=><button key={a.role} onClick={()=>choose(a)}><span className={`account-icon ${a.role}`}><UserRound/></span><span><b>{a.label}</b><small>{a.email} · {a.password}</small><em>{a.access}</em></span><strong>Use →</strong></button>)}</div><div className="secure-note"><ShieldCheck/>Role-based permissions are enforced throughout the console.</div></div></div></div>
}

function MiniChart() {
  const points = [62,65,64,68,70,69,74,72,77,75,80,79,83,82,86]
  return <svg viewBox="0 0 420 120" className="chart" role="img" aria-label="Link quality over the current pass">
    <defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#29d7c8" stopOpacity=".36"/><stop offset="1" stopColor="#29d7c8" stopOpacity="0"/></linearGradient></defs>
    {[20,50,80,110].map(y=><line key={y} x1="0" x2="420" y1={y} y2={y} stroke="#ffffff0c" />)}
    <path d={`M0 120 L${points.map((p,i)=>`${i*30},${120-p}`).join(' L')} L420 120 Z`} fill="url(#area)"/>
    <polyline points={points.map((p,i)=>`${i*30},${120-p}`).join(' ')} fill="none" stroke="#29d7c8" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
}

function OrbitalGraphic() {
  return <div className="orbit-graphic" aria-label="Satellite orbit visualization">
    <div className="stars"/><div className="planet"><span>EARTH</span></div><div className="orbit-ring"><div className="sat"><Satellite size={17}/></div></div>
    <div className="orbit-label label-a">APOGEE <strong>516 km</strong></div><div className="orbit-label label-b">VELOCITY <strong>7.61 km/s</strong></div>
  </div>
}

function PageIntro({kicker,title,copy}:{kicker:string,title:string,copy:string}){return <div className="page-intro"><small>{kicker}</small><h2>{title}</h2><p>{copy}</p></div>}

function WorkspaceView({active,data,onSimulate,onAddStation,simulating}:{active:string,data:Dashboard,onSimulate:()=>void,onAddStation:()=>void,simulating:boolean}) {
  if(active==='Telemetry') return <div className="workspace-page"><PageIntro kicker="SPACECRAFT HEALTH" title="Live telemetry" copy="Latest housekeeping samples received from SomaiyaSat, with flight-envelope checks and link diagnostics."/><section className="metrics detail-metrics"><article><div className="metric-icon teal"><BatteryCharging/></div><div><small>BATTERY</small><strong>{data.telemetry.battery}%</strong><span>Nominal reserve</span></div></article><article><div className="metric-icon amber"><ThermometerSun/></div><div><small>TEMPERATURE</small><strong>{data.telemetry.temperature}°C</strong><span>Inside envelope</span></div></article><article><div className="metric-icon blue"><Signal/></div><div><small>LINK QUALITY</small><strong>{data.telemetry.linkQuality}%</strong><span>Strong downlink</span></div></article><article><div className="metric-icon violet"><Gauge/></div><div><small>POWER DRAW</small><strong>{data.telemetry.powerDraw}W</strong><span>Sub-1W target</span></div></article></section><section className="panel telemetry-detail"><div className="panel-title"><div><small>HOUSEKEEPING STREAM</small><h3>Current orbital pass</h3></div><span className="tag"><CircleDot/>LIVE</span></div><MiniChart/><div className="chart-labels"><span>AOS · 10:26</span><span>Peak elevation · 64°</span><span>LOS · 10:39</span></div><div className="telemetry-grid"><div><small>RSSI</small><b>−82 dBm</b></div><div><small>SNR</small><b>+11.4 dB</b></div><div><small>BUS VOLTAGE</small><b>3.82 V</b></div><div><small>ATTITUDE</small><b>Stable</b></div><div><small>PACKET LOSS</small><b>0.8%</b></div><div><small>STORAGE</small><b>{data.telemetry.storage}%</b></div></div></section></div>
  if(active==='Ground stations') return <div className="workspace-page"><PageIntro kicker="GROUND SEGMENT" title="Station network" copy="Manage stations, track pass readiness, and monitor the live radio link."/><section className="panel stations-panel"><div className="panel-title"><div><small>{data.stations.length} REGISTERED STATIONS</small><h3>Global coverage</h3></div><button className="outline-btn" onClick={onAddStation}>+ Add station</button></div><div className="station-map"><div className="map-orbit"/><i className="pin p1">IN</i><i className="pin p2">FI</i><i className="pin p3">JP</i><span>Next scheduled contact · ReOrbit North at 12:44 UTC</span></div><div className="station-table"><div className="tr th"><span>STATION</span><span>STATUS</span><span>NEXT PASS</span><span>LINK</span><span>ELEVATION</span><span/></div>{data.stations.map(s=><div className="tr" key={s.id}><span className="station-name"><i>{s.code.slice(0,2)}</i><b>{s.name}<small>{s.code} · {s.city}</small></b></span><span><em className={s.status==='TRACKING'?'tracking':''}>{s.status}</em></span><span>{s.nextPass}</span><span>{s.signal?`${s.signal}%`:'—'}</span><span>{s.elevation?`${s.elevation}°`:'—'}</span><button aria-label={`Open ${s.name}`}><ChevronDown/></button></div>)}</div></section></div>
  if(active==='AI router') return <div className="workspace-page"><PageIntro kicker="AUTONOMOUS OPERATIONS" title="AI routing laboratory" copy="Test the bounded decision policy and inspect why each communication mode was selected."/><section className="router-layout"><article className="panel policy-card"><div className="panel-title"><div><small>POLICY INPUTS</small><h3>Scenario controls</h3></div><ShieldCheck/></div><label>Battery reserve <b>{data.telemetry.battery}%</b><input type="range" min="0" max="100" defaultValue={data.telemetry.battery}/></label><label>Link quality <b>{data.telemetry.linkQuality}%</b><input type="range" min="0" max="100" defaultValue={data.telemetry.linkQuality}/></label><label>Data urgency <b>Critical</b><input type="range" min="0" max="100" defaultValue="92"/></label><button className="simulate" onClick={onSimulate} disabled={simulating}><RefreshCw className={simulating?'spin':''}/>{simulating?'Evaluating…':'Evaluate routing policy'}</button></article><article className="panel"><div className="panel-title"><div><small>DECISION LOG</small><h3>Explainability trail</h3></div><Bot/></div><div className="decision-log">{data.decisions.slice(0,5).map(d=><div key={d.id}><span className={`mode-icon ${modeClass[d.selectedMode]}`}><Route/></span><p><b>{d.selectedMode} · score {d.score}</b><small>{d.reason}</small></p><em>{d.confidence}%<small>{d.createdAt}</small></em></div>)}</div></article></section></div>
  return <div className="workspace-page"><PageIntro kicker="MISSION DATABASE" title="Data explorer" copy="Browse the normalized operational records used by the dashboard and routing policy."/><div className="entity-tabs"><button className="active">Data queue <span>{data.queue.length}</span></button><button>Routing decisions <span>{data.decisions.length}</span></button><button>Ground stations <span>{data.stations.length}</span></button><button>Telemetry <span>3</span></button></div><section className="panel explorer"><div className="panel-title"><div><small>TABLE · DATA_QUEUE</small><h3>Pending mission data</h3></div><button className="outline-btn">Export CSV</button></div><div className="data-table"><div className="data-row data-head"><span>ID</span><span>PAYLOAD</span><span>MODE</span><span>SIZE</span><span>PRIORITY</span><span>STATUS</span></div>{data.queue.map(q=><div className="data-row" key={q.id}><span>#{String(q.id).padStart(4,'0')}</span><span><b>{q.label}</b></span><span><em className={modeClass[q.type]}>{q.type}</em></span><span>{q.sizeKb} KB</span><span>{q.priority}</span><span>{q.status}</span></div>)}</div></section></div>
}

function App() {
  const [session, setSession] = useState<Session|null>(()=>{try{return JSON.parse(sessionStorage.getItem('somaiyasat-session')||'null')}catch{return null}})
  const [data, setData] = useState<Dashboard>(fallback)
  const [active, setActive] = useState('Overview')
  const [mobile, setMobile] = useState(false)
  const [simulating, setSimulating] = useState(false)
  const [toast, setToast] = useState('')
  const [stationModal, setStationModal] = useState(false)
  const [stationName, setStationName] = useState('')
  const [searchOpen, setSearchOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const nav = ['Overview','Telemetry','Ground stations','AI router','Data explorer']

  useEffect(() => { fetch('/api/dashboard').then(r=>r.ok?r.json():Promise.reject()).then(setData).catch(()=>{}) }, [])
  useEffect(()=>{const onKey=(e:KeyboardEvent)=>{if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='k'){e.preventDefault();setSearchOpen(true)}if(e.key==='Escape')setSearchOpen(false)};window.addEventListener('keydown',onKey);return()=>window.removeEventListener('keydown',onKey)},[])
  const activeQueue = useMemo(()=>data.queue.filter(q=>q.status!=='DELIVERED'),[data])
  const simulate = async () => {
    if(session?.role==='observer'){setToast('Read-only observers cannot run simulations');setTimeout(()=>setToast(''),2500);return}
    setSimulating(true)
    try { const r=await fetch('/api/routing/simulate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({battery:data.telemetry.battery,linkQuality:data.telemetry.linkQuality})}); if(r.ok){const d=await r.json();setData(v=>({...v,decisions:[d,...v.decisions]}))} } catch {}
    setTimeout(()=>{setSimulating(false);setToast('Routing policy evaluated · safe constraints passed');setTimeout(()=>setToast(''),2800)},650)
  }
  const addStation = async () => {
    if(session?.role!=='operator'){setToast('Mission Operator permission required');setTimeout(()=>setToast(''),2500);return}
    if(!stationName.trim()) return
    const station: Station={id:Date.now(),code:`GS-${data.stations.length+1}`,name:stationName,city:'New station',status:'READY',signal:0,elevation:0,nextPass:'Calculating…'}
    try { const r=await fetch('/api/stations',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(station)}); if(r.ok) Object.assign(station,await r.json()) } catch {}
    setData(v=>({...v,stations:[...v.stations,station]}));setStationName('');setStationModal(false);setToast('Ground station added');setTimeout(()=>setToast(''),2500)
  }
  const login=(s:Session)=>{sessionStorage.setItem('somaiyasat-session',JSON.stringify(s));setSession(s)}
  const logout=()=>{sessionStorage.removeItem('somaiyasat-session');setSession(null);setActive('Overview')}
  if(!session)return <LoginScreen onLogin={login}/>
  return <div className="app-shell">
    <aside className={mobile?'sidebar open':'sidebar'}>
      <div className="brand"><div className="brand-mark"><Orbit size={23}/></div><div><strong>SOMAIYA<span>SAT</span></strong><small>MISSION CONTROL</small></div><button className="close-mobile" onClick={()=>setMobile(false)}><X/></button></div>
      <div className="mission-chip"><span className="pulse"/><div><small>MISSION STATUS</small><strong>Spacecraft nominal</strong></div></div>
      <nav>{nav.map((n,i)=>{const I=[Globe2,Activity,Antenna,Bot,Database][i];return <button key={n} className={active===n?'active':''} onClick={()=>{setActive(n);setMobile(false)}}><I size={18}/>{n}</button>})}</nav>
      <div className="side-foot"><div className="pod-status"><div><Server size={17}/><span><small>SOMAIYAPOD</small><strong>Deployment complete</strong></span></div><ShieldCheck size={20}/></div><p>Autonomous Operations Console<br/>KJSIT × KJSSE × ReOrbit</p></div>
    </aside>
    <main>
      <header><button className="menu" onClick={()=>setMobile(true)}><Menu/></button><div><p>MISSION / SOMAIYASAT-1</p><h1>{active}</h1></div><div className="header-actions"><button className="search" onClick={()=>setSearchOpen(true)}><Search size={17}/>Search records <kbd>⌘ K</kbd></button><div className="live"><span/> LIVE LINK</div><div className="user-menu"><div className="avatar">{session.name.split(' ').map(x=>x[0]).slice(0,2).join('')}</div><span><b>{session.name}</b><small>{session.label}</small></span><button onClick={logout} title="Sign out"><LogOut/></button></div></div></header>
      <div className="content">
        {active!=='Overview'&&<WorkspaceView active={active} data={data} onSimulate={simulate} onAddStation={()=>setStationModal(true)} simulating={simulating}/>} 
        <div className={active==='Overview'?'overview-content':'hidden'}>
        <section className="hero-grid">
          <div className="hero-card"><div className="hero-copy"><div className="eyebrow"><span>LEO · ORBIT {data.satellite.orbit}</span><span className="nominal">● {data.satellite.state}</span></div><h2>Eyes on <em>SomaiyaSat.</em></h2><p>Autonomous inter-satellite routing and multi-mode amateur radio operations, unified in one explainable mission console.</p><div className="hero-meta"><div><small>CURRENT PASS</small><strong>Mumbai · 42° elevation</strong></div><div><small>MISSION ELAPSED</small><strong>{data.satellite.uptime}</strong></div></div></div><OrbitalGraphic/></div>
          <div className="decision-card"><div className="card-head"><div><small>AI ROUTER · LIVE DECISION</small><h3>Transmission strategy</h3></div><Bot/></div><div className="route-choice"><div className={`mode-icon ${modeClass[data.decisions[0].selectedMode]}`}><Radio/></div><div><small>SELECTED MODE</small><strong>{data.decisions[0].selectedMode} priority downlink</strong></div><div className="confidence">{data.decisions[0].confidence}%<small>confidence</small></div></div><p className="reason">“{data.decisions[0].reason}”</p><div className="factor-row"><span><BatteryCharging/>Power <b>GOOD</b></span><span><Signal/>Link <b>STRONG</b></span><span><Clock3/>Urgency <b>CRITICAL</b></span></div><button className="simulate" onClick={simulate} disabled={simulating}><RefreshCw className={simulating?'spin':''}/>{simulating?'Evaluating policy…':'Run routing simulation'}</button></div>
        </section>
        <section className="metrics">
          <article><div className="metric-icon teal"><BatteryCharging/></div><div><small>BATTERY RESERVE</small><strong>{data.telemetry.battery}<sup>%</sup></strong><span>+3.2% in sunlight</span></div><div className="ring" style={{'--p':`${data.telemetry.battery*3.6}deg`} as React.CSSProperties}/></article>
          <article><div className="metric-icon amber"><ThermometerSun/></div><div><small>BUS TEMPERATURE</small><strong>{data.telemetry.temperature}<sup>°C</sup></strong><span>Within flight envelope</span></div><div className="spark">⌁⌁</div></article>
          <article><div className="metric-icon blue"><Signal/></div><div><small>LINK QUALITY</small><strong>{data.telemetry.linkQuality}<sup>%</sup></strong><span>+8% since AOS</span></div><div className="bars"><i/><i/><i/><i/><i/></div></article>
          <article><div className="metric-icon violet"><Database/></div><div><small>STORAGE USED</small><strong>{data.telemetry.storage}<sup>%</sup></strong><span>18.7 MB available</span></div><div className="tiny-progress"><i style={{width:`${data.telemetry.storage}%`}}/></div></article>
        </section>
        <section className="ops-grid">
          <article className="panel link-panel"><div className="panel-title"><div><small>PASS TELEMETRY</small><h3>Link performance</h3></div><span className="tag"><CircleDot/>IN-MUM</span></div><MiniChart/><div className="chart-labels"><span>AOS 10:26</span><span>NOW 10:31</span><span>LOS 10:39</span></div><div className="link-stats"><div><small>RSSI</small><b>−82 dBm</b></div><div><small>SNR</small><b>+11.4 dB</b></div><div><small>PACKETS</small><b>1,284</b></div><div><small>LOSS</small><b className="good">0.8%</b></div></div></article>
          <article className="panel queue-panel"><div className="panel-title"><div><small>PRIORITY SCHEDULER</small><h3>Downlink queue</h3></div><span>{activeQueue.length} pending</span></div><div className="queue-list">{activeQueue.map((q:QueueItem)=><div className="queue-item" key={q.id}><div className={`mode-icon ${modeClass[q.type]}`}><Radio/></div><div className="queue-main"><div><strong>{q.label}</strong><span>{q.sizeKb} KB</span></div><small>{q.type} · {q.deadline}</small></div><div className="priority"><i style={{width:`${q.priority}%`}}/><small>{q.priority}</small></div></div>)}</div></article>
        </section>
        <section className="panel stations-panel"><div className="panel-title"><div><small>GROUND SEGMENT</small><h3>Station network</h3></div><button className="outline-btn" onClick={()=>setStationModal(true)}>+ Add station</button></div><div className="station-table"><div className="tr th"><span>STATION</span><span>STATUS</span><span>NEXT PASS</span><span>LINK</span><span>ELEVATION</span><span/></div>{data.stations.map(s=><div className="tr" key={s.id}><span className="station-name"><i>{s.code.slice(0,2)}</i><b>{s.name}<small>{s.code} · {s.city}</small></b></span><span><em className={s.status==='TRACKING'?'tracking':''}>{s.status}</em></span><span>{s.nextPass}</span><span>{s.signal?`${s.signal}%`:'—'}</span><span>{s.elevation?`${s.elevation}°`:'—'}</span><button><ChevronDown/></button></div>)}</div></section>
        <footer><span><Zap/>Telemetry refreshed 8 seconds ago</span><span>Mission database · PostgreSQL</span></footer>
        </div>
      </div>
    </main>
    {stationModal&&<div className="modal-backdrop" onClick={()=>setStationModal(false)}><div className="modal" onClick={e=>e.stopPropagation()}><div className="modal-icon"><Antenna/></div><h3>Register ground station</h3><p>Add a station to the mission network. Pass calculations will begin after registration.</p><label>Station name<input autoFocus value={stationName} onChange={e=>setStationName(e.target.value)} placeholder="e.g. Pune HAM Ground" onKeyDown={e=>e.key==='Enter'&&addStation()}/></label><div><button className="ghost" onClick={()=>setStationModal(false)}>Cancel</button><button className="simulate" onClick={addStation}>Register station</button></div></div></div>}
    {searchOpen&&<div className="search-backdrop" onClick={()=>setSearchOpen(false)}><div className="command-search" onClick={e=>e.stopPropagation()}><div><Search/><input autoFocus value={searchQuery} onChange={e=>setSearchQuery(e.target.value)} placeholder="Search stations, payloads, modes…"/><kbd>ESC</kbd></div><small>SEARCH RESULTS</small>{[...data.stations.map(s=>({title:s.name,meta:`Ground station · ${s.code}`,page:'Ground stations'})),...data.queue.map(q=>({title:q.label,meta:`${q.type} · ${q.status}`,page:'Data explorer'}))].filter(x=>(x.title+x.meta).toLowerCase().includes(searchQuery.toLowerCase())).slice(0,6).map(x=><button key={x.title} onClick={()=>{setActive(x.page);setSearchOpen(false);setSearchQuery('')}}><span><b>{x.title}</b><small>{x.meta}</small></span><em>Open →</em></button>)}</div></div>}
    {toast&&<div className="toast"><ShieldCheck/>{toast}</div>}
  </div>
}

export default App
