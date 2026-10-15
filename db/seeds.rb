# Idempotent: shipments are found by identifier, and a trail is only published
# when the shipment has no locations yet. Safe to run repeatedly.
#
# Seeds create only shipments. Trails are published to the `shipment_locations`
# Kafka topic, so locations and status changes are written by the consumer
# (`docker compose up -d karafka` must be running) and never directly to the DB.

SAMPLE_DIR = Rails.root.join("db/seeds/routes")

CHICAGO = { latitude: 41.8781, longitude: -87.6298, address: "Chicago, Cook County, Illinois, USA" }.freeze
ATLANTA = { latitude: 33.7490, longitude: -84.3880, address: "Atlanta, Fulton County, Georgia, USA" }.freeze
SEATTLE = { latitude: 47.6062, longitude: -122.3321, address: "Seattle, King County, Washington, USA" }.freeze
PORTLAND = { latitude: 45.5152, longitude: -122.6784, address: "Portland, Multnomah County, Oregon, USA" }.freeze

SEED_SHIPMENTS = [
  { identifier: "SEED-0001", weight: 120.5, height: 90.0, file: "Locations-1.json" },
  { identifier: "SEED-0002", weight: 340.0, height: 150.0, file: "Locations-2.json" },
  { identifier: "SEED-0003", weight: 75.2, height: 60.0, file: "Locations-3.json" },
  { identifier: "SEED-0004", weight: 210.0, height: 110.0, from: CHICAGO, to: ATLANTA },
  { identifier: "SEED-0005", weight: 48.8, height: 45.0, from: SEATTLE, to: PORTLAND }
].freeze

SEED_SHIPMENTS.each_with_index do |spec, index|
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

  # Timestamps are anchored to the shipment's created_at (not "now"), so a re-run
  # before the consumer has caught up republishes identical messages, which the
  # unique [shipment_id, recorded_at] index then ignores.
  rows = builder.timestamped(points, ends_at: shipment.created_at.change(usec: 0))
  messages = rows.map do |row|
    {
      topic: ShipmentLocationsConsumer::TOPIC,
      key: shipment.shipment_identifier,
      payload: {
        shipment_identifier: shipment.shipment_identifier,
        latitude: row[:latitude], longitude: row[:longitude],
        recorded_at: (row[:recorded_at].to_f * 1000).round,
        address: row[:address], speed: row[:speed]
      }.compact.to_json
    }
  end
  Karafka.producer.produce_many_sync(messages)
  puts "#{shipment.shipment_identifier}: published #{messages.size} points to Kafka"
end
