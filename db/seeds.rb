# Idempotent: shipments are found by identifier, and a trail is only inserted
# when the shipment has none. Safe to run repeatedly.
#
# TEMPORARY: locations are written straight to the DB. Step 8 replaces this with
# publishing to Kafka so that no location bypasses the consumer.
require_relative "seeds/trail_builder"

SAMPLE_DIR = Rails.root.join("sampleRoutes")

CHICAGO = { latitude: 41.8781, longitude: -87.6298, address: "Chicago, Cook County, Illinois, USA" }.freeze
ATLANTA = { latitude: 33.7490, longitude: -84.3880, address: "Atlanta, Fulton County, Georgia, USA" }.freeze
SEATTLE = { latitude: 47.6062, longitude: -122.3321, address: "Seattle, King County, Washington, USA" }.freeze
PORTLAND = { latitude: 45.5152, longitude: -122.6784, address: "Portland, Multnomah County, Oregon, USA" }.freeze

SHIPMENTS = [
  { identifier: "SEED-0001", weight: 120.5, height: 90.0, file: "Locations-1.json" },
  { identifier: "SEED-0002", weight: 340.0, height: 150.0, file: "Locations-2.json" },
  { identifier: "SEED-0003", weight: 75.2, height: 60.0, file: "Locations-3.json" },
  { identifier: "SEED-0004", weight: 210.0, height: 110.0, from: CHICAGO, to: ATLANTA },
  { identifier: "SEED-0005", weight: 48.8, height: 45.0, from: SEATTLE, to: PORTLAND }
].freeze

SHIPMENTS.each_with_index do |spec, index|
  builder = TrailBuilder.new(seed: index)
  points = if spec[:file]
    builder.from_file(SAMPLE_DIR.join(spec[:file]))
  else
    builder.interpolate(spec[:from], spec[:to])
  end

  shipment = Shipment.find_or_create_by!(shipment_identifier: spec[:identifier]) do |s|
    s.weight = spec[:weight]
    s.height = spec[:height]
    s.source_address = points.first[:address]
    s.destination_address = points.last[:address]
    s.source_latitude = points.first[:latitude]
    s.source_longitude = points.first[:longitude]
    s.destination_latitude = points.last[:latitude]
    s.destination_longitude = points.last[:longitude]
  end

  next if shipment.locations.exists?

  rows = builder.timestamped(points, ends_at: Time.current - (index + 1).hours)
  ShipmentLocation.insert_all(rows.map { |r| r.merge(shipment_id: shipment.id) })
end
