namespace :simulator do
  desc "Publish a GPS trail for a shipment to Kafka: simulator:run[SHIPMENT_ID,INTERVAL_SECONDS]"
  task :run, %i[shipment_identifier interval] => :environment do |_t, args|
    identifier = args[:shipment_identifier] or abort("usage: rake simulator:run[SHIPMENT_ID,INTERVAL_SECONDS]")
    interval = Float(args[:interval] || 1)
    shipment = Shipment.find_by!(shipment_identifier: identifier)

    builder = TrailBuilder.new(seed: shipment.id)
    points = builder.interpolate(
      { latitude: shipment.source_latitude, longitude: shipment.source_longitude, address: shipment.source_address },
      { latitude: shipment.destination_latitude, longitude: shipment.destination_longitude, address: shipment.destination_address }
    )
    # Only speed is taken from the builder; each point is stamped when it is sent.
    points = builder.timestamped(points, ends_at: Time.current)

    points.each_with_index do |point, i|
      payload = {
        shipment_identifier: shipment.shipment_identifier,
        latitude: point[:latitude], longitude: point[:longitude],
        recorded_at: (Time.current.to_f * 1000).to_i,
        address: point[:address], speed: point[:speed]
      }.compact
      Karafka.producer.produce_sync(topic: ShipmentLocationsConsumer::TOPIC, key: shipment.shipment_identifier, payload: payload.to_json)
      puts "[#{i + 1}/#{points.size}] #{payload[:latitude].round(4)}, #{payload[:longitude].round(4)}"
      sleep interval unless i == points.size - 1
    end
  end
end
