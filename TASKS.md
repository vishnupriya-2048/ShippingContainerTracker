# TASKS.md — Shipment Tracker: feature roadmap (do in order)

Give this with `README.md` (assignment) and `setup.md` (environment). Work **one branch at a time**; merge to `main` before starting the next. After each step: run the app, click through it, commit, push.

**Rules for Claude when using this file:** do one step only, explain new concepts (Rails/Kafka/Docker/Stimulus) in plain words before the code, keep diffs small, and stop for the user's confirmation at each checkpoint.

## Where does Kafka fit?
Not at the start. The assignment says *all location updates must flow through Kafka — no direct DB writes*. So:
1. Steps 1-5 build the app and screens using **seed data written directly to the DB** (temporary shortcut, so you can see something on the map).
2. Step 6 builds the geofence logic as a plain Ruby class, with tests, **before** Kafka — it's pure logic.
3. Step 7 adds Kafka: the consumer calls the same geofence class, and seeds switch to publishing to Kafka. From then on, no direct DB writes for locations.

Building the screens first means that when Kafka goes in, you can watch dots appear on the map and know it works.

---

## Step 0 — Environment (`setup.md`)
Branch: `main`. Done when localhost:3000 shows the Rails page. Commit the empty app.

## Step 1 — `feature/shipment-model-crud`
Barebones backend only: DB + endpoints, plain unstyled views are fine.
- [ ] Generate `Shipment` with all fields from the README table; `shipment_identifier` unique + required (DB unique index and model validation).
- [ ] `current_status` as a Rails enum: `prepared, picked_up, in_transit, out_for_delivery, delivered, exception` (default `prepared`).
- [ ] Validations: required fields, numeric weight/height, latitude -90..90, longitude -180..180.
- [ ] Routes + `ShipmentsController`: index, show, new/create, edit/update, destroy (`resources :shipments`).
- [ ] Plain views: list, show, form.
- [ ] Model tests (validations, enum).
- Checkpoint: create, edit and delete a shipment in the browser. Concepts: migration, model, controller, route, view, enum.

## Step 2 — `feature/location-and-status-models`
- [ ] Generate `ShipmentLocation` (lat, lng, `recorded_at`, address, speed, `shipment_id` FK) — index on `[shipment_id, recorded_at]`.
- [ ] Generate `ShipmentStatusHistory` (status, lat, lng, address, notes, `changed_at`, `shipment_id` FK).
- [ ] Associations: `Shipment has_many :locations, :status_histories`; `dependent: :destroy`; ordered scopes.
- [ ] `Shipment#latest_location` helper.
- [ ] Model tests.
- Checkpoint: create records in `rails console` and read them back.

## Step 3 — `feature/seed-data`
- [ ] Use the attached Locations JSON files from the assignment if provided; otherwise generate a realistic path between source and destination (>= 50 points per shipment, with timestamps and speed).
- [ ] `db/seeds.rb` creates ~5 shipments with trails. **Temporary**: writes locations directly to the DB (replaced in Step 8).
- [ ] Seeds are idempotent (can run twice without duplicates).
- Checkpoint: `db:seed`, then check counts in the console. Status history stays empty until Step 6/7.

## Step 4 — `feature/dashboard`
`/shipments` per README.
- [ ] Set `shipments#index` as root.
- [ ] Layout loads Google Maps JS using `ENV["MAPS_JS_API_KEY"]` (script tag in layout/partial).
- [ ] Tailwind table/cards: identifier, status badge, source -> destination, last location timestamp.
- [ ] Map shows one marker per shipment at its latest location.
- [ ] Stimulus `map_controller`: initializes map, adds markers; clicking a list row highlights + centers that marker (use Stimulus `targets`, `values`, `actions`).
- [ ] Avoid N+1 queries when loading latest locations.
- Checkpoint: the key is verified here — if the map is gray or shows a watermark, check `setup.md` section 12.

## Step 5 — `feature/shipment-detail`
`/shipments/:id` per README layout.
- [ ] Header with identifier; metadata section (weight, height, source, destination, status).
- [ ] Map: polyline through all locations with directional arrows, current-location marker, source/destination markers.
- [ ] Pass location data to Stimulus as JSON (data values) — no inline JS.
- [ ] Reuse the map controller from Step 4 where possible (extract shared code).
- Checkpoint: the trail draws correctly for each seeded shipment.

## Step 6 — `feature/geofence-service` (pure Ruby, no Kafka yet)
- [ ] `Geo::Haversine.distance_m(lat1, lng1, lat2, lng2)`; unit tests with known distances.
- [ ] `GeofenceEvaluator` — given a shipment + a new point, returns the new status or nil:
  - <= 500 m from source -> `prepared`
  - >= 1 km from source -> `picked_up`
  - >= 3 km from source -> `in_transit`
  - <= 2 km from destination -> `out_for_delivery`
  - <= 500 m from destination -> `delivered`
  - `exception`: manual override (and, bonus: route deviation).
- [ ] Define the rule order and "no regression" (a delivered shipment never goes back); document the decision.
- [ ] `LocationIngestor` service: takes a validated payload -> creates `ShipmentLocation` -> evaluates geofence -> creates `ShipmentStatusHistory` + updates `current_status` in one DB transaction.
- [ ] Idempotency: unique index on `[shipment_id, recorded_at]` so replayed messages don't duplicate.
- [ ] Tests for each transition and for duplicates.
- Checkpoint: in the console, call `LocationIngestor` with a few points and see status history appear.

## Step 7 — `feature/kafka-integration`
- [ ] Remove the generated `example` consumer and topic route.
- [ ] Topic `shipment_locations` (use several partitions, keyed by `shipment_identifier` so one shipment's messages stay ordered).
- [ ] `ShipmentLocationsConsumer`: parse JSON, validate payload (required fields, shipment exists, numeric ranges), call `LocationIngestor`; send bad messages to a log/dead-letter topic instead of crashing.
- [ ] Simulator (producer): a rake task `rake simulator:run[shipment_identifier]` that publishes the trail's points at an interval, with the README's JSON format (epoch milliseconds).
- [ ] Run via `docker compose up -d karafka`.
- [ ] Integration test: publish -> consume -> records exist.
- Checkpoint: start the simulator and watch locations and status changes appear in the DB.

## Step 8 — `feature/seeds-via-kafka`
- [ ] Seeds create only shipments; trails and statuses come from publishing to Kafka (so no direct DB writes for locations).
- [ ] Update setup instructions in the project README.

## Step 9 — `feature/status-history-tab`
Detail page tabs (README).
- [ ] Stimulus `tabs_controller`: switch panels without reloading the page or resetting the map.
- [ ] **Status History** tab: chronological list — status, timestamp, address, notes; clicking centers the map there.
- [ ] Map shows status-change markers with different colors/icons per status, simultaneously with the trail.

## Step 10 — `feature/location-trail-tab`
- [ ] **Location Trail** tab: all coordinates with timestamps and speed (if present).
- [ ] Clicking a row highlights that point on the map.
- [ ] Handle long lists (scrolling container, or pagination).

## Step 11 — `feature/polish-and-docs`
- [ ] UX pass: empty states, loading state, status colors, responsive layout.
- [ ] Manual "mark as exception" action (README `exception` status).
- [ ] Project README: setup (`docker compose up`, seed, simulator), design decisions, trade-offs, next steps for production (Kafka replication, auth, dead-letter handling, etc.).
- [ ] Screenshots or a short demo recording.

---

## Bonus (only after the above is solid)
Pick any, one branch each:
- [ ] `feature/live-updates` — ActionCable (Solid Cable is already in Rails 8): broadcast on new location/status; map marker moves live. (Or simple polling first.)
- [ ] `feature/dashboard-search-filter` — filter by status, search by identifier.
- [ ] `feature/status-timeline` — timeline visualization with icons.
- [ ] `feature/email-notifications` — mailer on status change (use `letter_opener` in dev).
- [ ] `feature/multi-partition-concurrency` — more partitions + several Karafka consumers; demonstrate concurrent shipments.
- [ ] `feature/route-deviation-exception` — auto `exception` when far from the expected path.

## Git workflow per feature
```powershell
git checkout main
git pull
git checkout -b feature/<name>
# ...work...
git add -A
git commit -m "Describe the change"
git push -u origin feature/<name>
# open a PR on GitHub, merge, then back to main
```
