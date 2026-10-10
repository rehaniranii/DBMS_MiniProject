import pg from 'pg'
import type { QueryResultRow } from 'pg'
import 'dotenv/config'
const { Pool } = pg
export const pool = process.env.DATABASE_URL ? new Pool({ connectionString: process.env.DATABASE_URL }) : null
export async function query<T extends QueryResultRow = QueryResultRow>(text: string, params: unknown[] = []) { if (!pool) throw new Error('DATABASE_URL is not configured'); return pool.query<T>(text, params) }
