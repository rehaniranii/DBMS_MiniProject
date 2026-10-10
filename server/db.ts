import pg from 'pg'
import type { QueryResultRow } from 'pg'
import { readFileSync } from 'node:fs'
import 'dotenv/config'
const { Pool } = pg
const isSupabase=process.env.DATABASE_URL?.includes('supabase.com')
const ssl=isSupabase?{ca:readFileSync(new URL('./certs/global-bundle.pem',import.meta.url),'utf8'),rejectUnauthorized:true}:undefined
export const pool = process.env.DATABASE_URL ? new Pool({ connectionString: process.env.DATABASE_URL,ssl,max:5 }) : null
export async function query<T extends QueryResultRow = QueryResultRow>(text: string, params: unknown[] = []) { if (!pool) throw new Error('DATABASE_URL is not configured'); return pool.query<T>(text, params) }
