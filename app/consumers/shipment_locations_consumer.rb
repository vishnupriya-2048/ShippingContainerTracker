# frozen_string_literal: true

# Reads GPS points from `shipment_locations`. Each message is validated and handed
# to LocationRecorder (which also applies geofence status changes). A bad message
# is copied to the dead-letter topic with the reason, so one poison message never
# stops the partition.
class ShipmentLocationsConsumer < ApplicationConsumer
  DEAD_LETTER_TOPIC = "shipment_locations_dlq"

  def consume
    messages.each do |message|
      message = LocationMessage.parse(message.raw_payload)
      LocationRecorder.record(shipment: message.shipment, **message.attributes)
    rescue LocationMessage::Invalid, ActiveRecord::RecordInvalid => e
      dead_letter(message, e)
    end
  end

  private

  def dead_letter(message, error)
    Karafka.logger.warn("Dead-lettering message at #{message.partition}/#{message.offset}: #{error.message}")
    producer.produce_async(
      topic: DEAD_LETTER_TOPIC,
      key: message.key,
      payload: message.raw_payload.to_s,
      headers: { "error" => error.message.to_s }
    )
  end
end
