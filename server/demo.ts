type Mode = 'TT&C' | 'SSTV' | 'Codec2' | 'M17'

export const dashboard = {
  satellite: { name: 'SomaiyaSat-1', norad: 'PENDING', state: 'NOMINAL', orbit: 1847, uptime: '127d 08h' },
  telemetry: { battery: 78, temperature: 24.6, linkQuality: 86, storage: 41, powerDraw: 0.72 },
  deployment: { state: 'DEPLOYED', separationConfirmed: true, confirmedAt: '2026-08-06T09:42:18Z' },
  stations: [
    { id: 1, code: 'IN-MUM', name: 'Somaiya Ground', city: 'Mumbai, IN', status: 'TRACKING', signal: 86, elevation: 42, nextPass: 'Live · 07:18 left' },
    { id: 2, code: 'FI-HEL', name: 'ReOrbit North', city: 'Helsinki, FI', status: 'READY', signal: 0, elevation: 0, nextPass: '12:44 UTC' },
    { id: 3, code: 'JP-TOK', name: 'HAM Tokyo', city: 'Tokyo, JP', status: 'READY', signal: 0, elevation: 0, nextPass: '14:09 UTC' },
  ],
  queue: [
    { id: 1, type: 'TT&C' as Mode, label: 'Health beacon #1847', sizeKb: 18, priority: 100, deadline: 'Immediate', status: 'TRANSMITTING' },
    { id: 2, type: 'SSTV' as Mode, label: 'Western Ghats frame', sizeKb: 640, priority: 76, deadline: 'Next 2 passes', status: 'QUEUED' },
    { id: 3, type: 'Codec2' as Mode, label: 'HAM voice packet 05', sizeKb: 92, priority: 54, deadline: '18 min', status: 'QUEUED' },
    { id: 4, type: 'M17' as Mode, label: 'Digital relay bundle', sizeKb: 124, priority: 42, deadline: 'Best effort', status: 'QUEUED' },
  ],
  decisions: [{ id: 1, selectedMode: 'TT&C' as Mode, confidence: 94, score: 91, reason: 'Critical housekeeping is due; link margin and battery reserve are sufficient.', createdAt: '10:31:42 UTC' }],
}
