# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', '127.0.0.1:9092') }
    config.client_id = "shipment_tracker-#{Process.pid}-#{Socket.gethostname}"
    config.group_id = 'shipment_tracker_consumer'
    # Recreate consumers with each batch so Rails code reloading works in development.
    config.consumer_persistence = !Rails.env.development?
  end

  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new(log_polling: false))
  Karafka.producer.monitor.subscribe(
    WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger, log_messages: false)
  )

  routes.draw do
    topic ShipmentLocationsConsumer::TOPIC do
      consumer ShipmentLocationsConsumer
      # Invalid messages are dead-lettered by the consumer; this catches anything
      # unexpected after 3 attempts so one message can't block the partition.
      dead_letter_queue topic: ShipmentLocationsConsumer::DEAD_LETTER_TOPIC, max_retries: 3
    end
  end

  # Messages are keyed by shipment_identifier, so one shipment always lands on the
  # same partition and stays ordered while different shipments run in parallel.
  # Create/update the topics with `bundle exec karafka topics migrate`.
  declaratives.draw do
    topic ShipmentLocationsConsumer::TOPIC do
      partitions 3
      replication_factor 1
    end

    topic ShipmentLocationsConsumer::DEAD_LETTER_TOPIC do
      active false
      partitions 1
      replication_factor 1
    end
  end
end
