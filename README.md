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
(>= 50 points, from `sampleRoutes/` or generated) to the `shipment_locations` topic.
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
