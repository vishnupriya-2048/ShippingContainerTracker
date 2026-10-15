# Shipment Tracking Web Application — Take Home Assignment

Your task is to build a **Shipment Tracking Web Application** using the following stack:

- **Backend**: Ruby on Rails
- **Frontend**: TailwindCSS + StimulusJS
- **Maps**: Google Maps JavaScript API
- **Database**: PostgreSQL (preferred) or SQLite
- **Messaging/Event System**: Apache Kafka - Use (Karafka)

This assignment evaluates **end-to-end product ownership**, including backend modeling, frontend interactions, event-driven architecture, and thoughtful system design. The focus is on completeness, quality, architecture, and maintainability.

---

## Core Requirements

### 1. Shipment Model
A shipment represents a delivery from a **source address** to a **destination address**.

**Attributes**

| Field | Type | Notes |
|-------|------|-------|
| `shipment_identifier` | string | Unique, required |
| `weight` | float | In kilograms |
| `height` | float | In centimeters |
| `source_address` | string | Full address |
| `destination_address` | string | Full address |
| `source_latitude` | float | Source pickup coordinates |
| `source_longitude` | float | Source pickup coordinates |
| `destination_latitude` | float | Destination delivery coordinates |
| `destination_longitude` | float | Destination delivery coordinates |
| `current_status` | string / enum | Current status: `prepared`, `picked_up`, `in_transit`, `out_for_delivery`, `delivered`, `exception` |
| `created_at` | datetime | Shipment creation timestamp |
| `updated_at` | datetime | Last modification timestamp |

> Each shipment should have at least **50 location points** simulating the journey. See the attached Locations JSON files and feel free to use them.

---

### 2. ShipmentLocation Model
Tracks the GPS trail of a shipment during transit.

**Attributes**

| Field | Type | Notes |
|-------|------|-------|
| `latitude` | float | GPS latitude coordinate |
| `longitude` | float | GPS longitude coordinate |
| `recorded_at` | datetime or epoch in milliseconds | Chronological order |
| `shipment_id` | foreign key | belongs_to Shipment |
| `address` | string | Optional: reverse-geocoded address |
| `speed` | float | Optional: speed at this location (km/h) |

---

### 3. ShipmentStatusHistory Model
**New Model** - Tracks all status changes with location context.

**Attributes**

| Field | Type | Notes |
|-------|------|-------|
| `shipment_id` | foreign key | belongs_to Shipment |
| `status` | string / enum | Status at time of change: `prepared`, `picked_up`, `in_transit`, `out_for_delivery`, `delivered`, `exception` |
| `latitude` | float | Location where status changed |
| `longitude` | float | Location where status changed |
| `address` | string | Human-readable address of status change |
| `notes` | text | Optional: additional details about status change |
| `changed_at` | datetime | When the status changed |
| `created_at` | datetime | Record creation timestamp |

**Geofence-Based Status Transitions:**
- `prepared`: When shipment is **within 500m** of source address coordinates
- `picked_up`: When shipment is **1km outside** of source address coordinates
- `in_transit`: When shipment is **3km outside** of source address coordinates
- `out_for_delivery`: When shipment is **within 2km** of destination address coordinates
- `delivered`: When shipment is **within 500m** of destination address coordinates
- `exception`: Manual override or when shipment deviates significantly from expected route

---

## Screens

### Shipments Dashboard (`/shipments`)
- List all shipments with metadata:
  - Identifier
  - Current status
  - Source → Destination
  - Last known location timestamp
- **Google Map** showing the **latest location of each shipment**
- Clicking a shipment highlights and centers it on the map
- All map interactions powered by **StimulusJS**

---

### Shipment Detail (`/shipments/:id`)
**Layout**
```
[ Header: Shipment Identifier ]
[ Metadata section ]
[ Tabs: Status History | Location Trail ]
[ Google Map visualization ]
```

**Requirements**
- Metadata section: weight, height, source, destination, current status
- Tabs:
  - **Status History:** Chronological list of all status changes with:
    - Status name & timestamp
    - Location where status changed (address)
    - Optional notes/details
    - Clicking a status change centers map on that location
  - **Location Trail:** List all GPS coordinates with timestamps
    - Clicking a coordinate highlights that point on the map
    - Show speed if available
- Map Features:
  - Draw **polyline connecting all coordinates** with directional arrows
  - **Status change markers** with different colors/icons per status
  - **Current location marker** (latest GPS point)
  - Switching tabs does **not reload/reset** map state (Stimulus-managed)
  - Show both location trail AND status change locations simultaneously

---

## Kafka Integration (Event-Driven Shipment Updates)

All shipment location updates must flow through **Kafka** — no direct DB writes. Status changes are automatically triggered based on geofence rules.

### Kafka Topic: `shipment_locations`

#### Producer (Simulator)
- Simulates GPS devices sending regular location updates
- Example JSON message:
```json
{
  "shipment_identifier": "DHL-12345",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "recorded_at": 1729781200000, // EPOCH timestamp in milliseconds
  "address": "MG Road, Bangalore, Karnataka, India", // Optional
  "speed": 45.5 // Optional: km/h
}
```

#### Consumer & Geofence Processing
- Automatic status transitions when entering/leaving zones
- Listens to `shipment_locations` topic
- Validates payload and shipment existence
- Creates `ShipmentLocation` records
- **Automatic Status Updates via Geofencing:**
  - Calculates distance from source/destination coordinates
  - Triggers status changes when entering/exiting geofence zones
  - Creates `ShipmentStatusHistory` records automatically
  - Updates shipment's `current_status`

### Geofence Definitions

| Status | Geofence Rule | Distance from Reference Point |
|--------|---------------|------------------------------|
| `prepared` | Within source zone | ≤ 500m from source coordinates |
| `picked_up` | Outside source zone | ≥ 1km from source coordinates |
| `in_transit` | Far from source | ≥ 3km from source coordinates |
| `out_for_delivery` | Near destination zone | ≤ 2km from destination coordinates |
| `delivered` | At destination | ≤ 500m from destination coordinates |

### Optional / Bonus
- Multiple partitions/topics for concurrent streams
- Idempotent processing to avoid duplicate locations
- Real-time updates in frontend via ActionCable or polling

---

## Technical Guidelines

- **TailwindCSS** for all styling — no Bootstrap or other UI frameworks
- **StimulusJS** for all map interactions and status/location tab management
- Proper Rails conventions (models, controllers, partials, services)
- **Geofence Logic:** Implement distance calculation using Haversine formula or similar
- **Seeds:** Generate realistic shipments with source/destination coordinates and simulated GPS trails
- Keep code **clean, modular, maintainable**

---

## Deliverables

1. GitHub repository (public or private with access)
2. `README.md` including:
   - Setup instructions (`bin/setup`, DB seed, etc.)
   - Design decisions and architectural choices
   - Any trade-offs or next steps if production-ready
3. Optional: screenshots or short demo of the app

---



## Bonus Features (Optional)

- **Real-time Status Updates:** WebSocket notifications when status changes
- **Customer Notifications:** Email alerts on status changes
- Live map updates via ActionCable
- Dashboard search/filter functionality
- Timeline/status visualization with icons

---

We are looking for **clean structure, thoughtful architecture, and attention to UX**, not just raw code output.
Focus on realistic simulation of shipment updates, proper event-driven flow via Kafka, and an intuitive dashboard + detail map experience.
