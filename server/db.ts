import pg from 'pg'
import type { QueryResultRow } from 'pg'
import { readFileSync } from 'node:fs'
import 'dotenv/config'
const { Pool } = pg
const databaseUrl=process.env.DATABASE_URL
const isSupabase=databaseUrl?.includes('supabase.com')
const connectionString=isSupabase&&databaseUrl?(()=>{const url=new URL(databaseUrl);url.searchParams.delete('sslmode');return url.toString()})():databaseUrl
const ssl=isSupabase?{ca:readFileSync(new URL('./certs/supabase-prod-ca-2021.crt',import.meta.url),'utf8'),rejectUnauthorized:true}:undefined
export const pool = connectionString ? new Pool({ connectionString,ssl,max:5 }) : null
export async function query<T extends QueryResultRow = QueryResultRow>(text: string, params: unknown[] = []) { if (!pool) throw new Error('DATABASE_URL is not configured'); return pool.query<T>(text, params) }
