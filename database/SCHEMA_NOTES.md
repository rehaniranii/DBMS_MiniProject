# Database design notes

The final schema combines the original application model with the strongest parts of the contributed academic schema.

## Adopted from the contributed design

- Deployment is recorded in `deployment_events`, preserving multiple attempts and confirmation methods.
- `payloads` and `payload_communication_modes` model the many-to-many relationship between hardware and RF modes.
- `station_communication_modes` records which ground stations can receive each mode.
- `routing_decisions` stores the overall AI run; `routing_decision_items` stores packet-level transmit, defer, or reject actions.
- `transmission_logs` preserves retries, partial results, observed link quality, and failure reasons.
- Audit-oriented views expose pending data, AI rationale, transmission history, and mission performance.

## Improvements made during integration

- Consistent plural table names and generated numeric keys match the REST API.
- Foreign-key deletion behavior is explicit.
- `CHECK` constraints enforce percentages, time ordering, transmission action requirements, and deployment confirmation consistency.
- Mission-performance aggregates are calculated independently to avoid fan-out errors between decisions and transmissions.
- Seed timestamps are relative to execution time so the dashboard remains credible whenever the project is demonstrated.
- Demo data is clearly simulated and does not claim to be live flight telemetry.

## Files

- `schema.sql`: types, tables, relationships, constraints, indexes, and views.
- `seed.sql`: a sizeable related demonstration dataset covering eight stations, four days of telemetry, 34 passes, 44 queued/delivered packets, 29 AI decisions, decision items, commands, and transmission outcomes.
- `queries.sql`: reporting queries and safe parameterized insert examples.
