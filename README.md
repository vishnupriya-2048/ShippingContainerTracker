# Shipment Tracker

Rails 8 app that tracks shipments on a map. Every GPS point flows through Kafka (Karafka);
the consumer stores it and applies geofence rules to change the shipment's status.
See `ASSIGNMENT.md` for the full spec and `setup.md` for first-time environment setup
(Docker, `.env` with `MAPS_JS_API_KEY`).

## Run it

```powershell
docker compose up -d db kafka
docker compose run --rm --no-deps web bundle exec karafka topics migrate   # create topics (3 partitions + dead-letter)
docker compose up -d web karafka                                           # web on :3000, consumer in background
docker compose run --rm web bin/rails db:seed                              # create shipments + publish their trails
```

Open <http://localhost:3000>.

### How seeding works

`db:seed` creates 5 shipments (`SEED-0001`..`SEED-0005`) and **publishes** each trail
(>= 50 points, from `db/seeds/routes/` or generated) to the `shipment_locations` topic.
It never writes locations directly. The `karafka` container consumes them, creating
locations and status history, so after a few seconds the dashboard fills in.
If `karafka` is not running, the points wait in Kafka and are processed when it starts.

Seeds are safe to re-run: shipments are found by identifier, trails are skipped once a
shipment has locations, and republished points carry identical timestamps so the
unique `[shipment_id, recorded_at]` index ignores them.

### Live simulator

```powershell
docker compose run --rm web bin/rails "simulator:run[SEED-0001,1]"   # one point per second
```

Publishes a fresh trail (stamped with the current time) for an existing shipment.

### Tests

```powershell
docker compose run --rm web bin/rails test
```

### Reset the demo data

```powershell
docker compose run --rm web bin/rails runner "Shipment.destroy_all"
docker compose run --rm web bin/rails db:seed
```

## Kafka notes

- Topic `shipment_locations`, 3 partitions, keyed by `shipment_identifier` so one
  shipment's messages stay ordered.
- Invalid messages (bad JSON, unknown shipment, out-of-range values) are copied to
  `shipment_locations_dlq` with the reason in an `error` header.

## Design decisions

- **Everything flows through Kafka.** Locations are never written by the web app; the
  consumer calls `LocationRecorder`, which stores the point and applies the geofence
  in one transaction. Replays are harmless thanks to the unique `[shipment_id, recorded_at]` index.
- **Status rules live in one class** (`GeofenceEvaluator`): statuses only move forward,
  `delivered` is final, and `exception` is a manual override the geofence never changes
  (use "Mark as exception" on the shipment page). A shipment starts as `prepared`, so
  its status history begins at the first change (`picked_up`). The status cannot be
  edited by hand; it only changes through the geofence or "Mark as exception".
- **Validation in one place.** `LocationPayload` checks a message's shape and types;
  value ranges are enforced by the model validations and DB check constraints.
  Anything invalid goes to the dead-letter topic.
- **Thin front end.** Server-rendered ERB + Tailwind; Stimulus controllers (`map`, `trail`,
  `tabs`) get their data as JSON values, with no inline JS. Tabs only toggle `hidden`, so
  the map is never reloaded when switching tabs.
- **No N+1 on the dashboard**: `has_one :latest_location` uses a `DISTINCT ON` subquery.

## Trade-offs

- The detail page loads the full trail and history in one request; fine for hundreds of
  points, but long trails would need pagination or downsampling.
- The page does not update live; reload to see new points (ActionCable is the next step).
- Geofence status is evaluated per point with no route model, so a detour is not detected.

## Next steps for production

- Kafka: replication factor >= 3, `min.insync.replicas`, more partitions and consumers,
  TLS/SASL, and monitoring of consumer lag.
- Dead-letter handling: alert on `shipment_locations_dlq` and add a replay tool.
- Authentication and authorization (the app is open today); rate limiting on forms.
- Live updates via ActionCable, route-deviation `exception`, and error tracking.
- Secrets via credentials/secret manager; restrict the Maps key by HTTP referrer.

