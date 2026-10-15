# frozen_string_literal: true

# Reads GPS points from `shipment_locations`. Each message is validated and handed
# to LocationRecorder (which also applies geofence status changes). A bad message
# is copied to the dead-letter topic with the reason, so one poison message never
# stops the partition.
class ShipmentLocationsConsumer < ApplicationConsumer
  TOPIC = "shipment_locations"
  DEAD_LETTER_TOPIC = "shipment_locations_dlq"

  def consume
    messages.each do |kafka_message|
      payload = LocationPayload.parse(kafka_message.raw_payload)
      LocationRecorder.record(shipment: payload.shipment, **payload.attributes)
    rescue LocationPayload::Invalid, ActiveRecord::RecordInvalid => e
      dead_letter(kafka_message, e)
    end
  end

  private

  def dead_letter(kafka_message, error)
    Karafka.logger.warn("Dead-lettering message at #{kafka_message.partition}/#{kafka_message.offset}: #{error.message}")
    producer.produce_sync(
      topic: DEAD_LETTER_TOPIC,
      key: kafka_message.key,
      payload: kafka_message.raw_payload.to_s,
      headers: { "error" => error.message.to_s }
    )
  end
end
