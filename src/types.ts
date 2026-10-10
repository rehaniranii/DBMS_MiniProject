export type Mode = 'TT&C' | 'SSTV' | 'Codec2' | 'M17'
export type Station = { id: number; code: string; name: string; city: string; status: string; signal: number; elevation: number; nextPass: string }
export type QueueItem = { id: number; type: Mode; label: string; sizeKb: number; priority: number; deadline: string; status: string }
export type Decision = { id: number; selectedMode: Mode; confidence: number; score: number; reason: string; createdAt: string }
export type Dashboard = {
  satellite: { name: string; norad: string; state: string; orbit: number; uptime: string }
  telemetry: { battery: number; temperature: number; linkQuality: number; storage: number; powerDraw: number }
  deployment: { state: string; separationConfirmed: boolean; confirmedAt: string }
  stations: Station[]; queue: QueueItem[]; decisions: Decision[]
}
