# Parses one raw `shipment_locations` Kafka message (README JSON format,
# recorded_at in epoch milliseconds) and checks its shape and types. Value ranges
# are left to the ShipmentLocation validations. Raises LocationPayload::Invalid with
# a human-readable reason for anything that should go to the dead-letter topic.
class LocationPayload
  class Invalid < StandardError; end

  MAX_EPOCH_MS = 253_402_300_799_999 # 9999-12-31T23:59:59.999Z, the last time Postgres can store

  attr_reader :shipment, :attributes

  def self.parse(raw)
    data = JSON.parse(raw.to_s)
    raise Invalid, "payload must be a JSON object" unless data.is_a?(Hash)

    new(
      shipment: find_shipment(data["shipment_identifier"]),
      attributes: {
        latitude: number!(data, "latitude"),
        longitude: number!(data, "longitude"),
        recorded_at: time_from_ms(epoch_ms!(data, "recorded_at")),
        address: optional!(data, "address", String),
        speed: optional!(data, "speed", Numeric)
      }
    )
  rescue JSON::ParserError => e
    raise Invalid, "malformed JSON: #{e.message.lines.first.strip}"
  end

  def initialize(shipment:, attributes:)
    @shipment = shipment
    @attributes = attributes
  end

  def self.find_shipment(identifier)
    raise Invalid, "shipment_identifier is required" unless identifier.is_a?(String) && identifier.present?

    Shipment.find_by(shipment_identifier: identifier) or raise Invalid, "unknown shipment #{identifier}"
  end

  def self.number!(data, key)
    value = data[key]
    raise Invalid, "#{key} must be a number" unless value.is_a?(Numeric)

    value
  end

  def self.epoch_ms!(data, key)
    value = data[key]
    raise Invalid, "#{key} must be epoch milliseconds (integer)" unless value.is_a?(Integer) && value.between?(1, MAX_EPOCH_MS)

    value
  end

  # Integer arithmetic, so no millisecond is lost to float rounding (the unique
  # [shipment_id, recorded_at] index compares exact values).
  def self.time_from_ms(ms)
    Time.at(ms / 1000, ms % 1000, :millisecond).utc
  end

  def self.optional!(data, key, type)
    value = data[key]
    raise Invalid, "#{key} must be a #{type == String ? 'string' : 'number'}" unless value.nil? || value.is_a?(type)

    value
  end

  private_class_method :find_shipment, :number!, :epoch_ms!, :time_from_ms, :optional!
end
