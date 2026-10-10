# SomaiyaSat Mission Control

A full-stack DBMS mini-project for the SomaiyaSat PocketQube and SomaiyaPod deployer. The application demonstrates autonomous AI-based transmission scheduling across TT&C, SSTV, Codec2, and M17 communication modes.

## Stack

- React 19 + TypeScript + Vite
- Express 5 REST API
- PostgreSQL 16 with constraints, indexes, views, and relational seed data
- Docker Compose for reproducible local database setup

## Quick start

```bash
npm install
cp .env.example .env
npm run dev
```

The default `.env.example` uses `USE_DEMO_DATA=true`, so the complete interface runs without PostgreSQL. To use the database:

```bash
docker compose up -d
```

Then set `USE_DEMO_DATA=false` and keep the provided `DATABASE_URL`.

Frontend: http://localhost:5173  
API: http://localhost:4000/api/health

## Relational model

The schema models satellites, deployers and auditable deployment events; payloads and their supported modes; telemetry; ground stations and station-mode capabilities; passes; prioritized data; AI routing decisions and packet-level decision items; operator commands; and retryable transmission attempts. Foreign keys use deliberate deletion rules, while checks constrain percentages, packet counts, pass windows, action requirements, and deployment confirmation.

`database/seed.sql` contains realistic simulated inserts. `database/queries.sql` contains reporting queries plus safe parameterized insert examples for stations, telemetry, and queued mission data.

## API

| Method | Route | Purpose |
|---|---|---|
| GET | `/api/dashboard` | Mission summary and recent operational data |
| GET | `/api/stations` | List ground stations |
| POST | `/api/stations` | Create a ground station |
| PUT | `/api/stations/:id` | Update a ground station |
| DELETE | `/api/stations/:id` | Delete a ground station |
| POST | `/api/routing/simulate` | Evaluate the bounded routing policy |
| GET | `/api/health` | API/database mode health check |

## AI policy demonstration

The simulation is intentionally explainable and bounded: critical TT&C is preferred under low-power conditions, high-quality links permit SSTV, and moderate links use resilient Codec2. Production flight software would combine this fail-safe policy with a validated compact model, watchdogs, and operator overrides.
