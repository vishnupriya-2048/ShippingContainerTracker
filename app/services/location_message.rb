require "json"

# Parses and validates one raw `shipment_locations` Kafka message (README JSON
# format, recorded_at in epoch milliseconds). Raises LocationMessage::Invalid
# with a human-readable reason for anything that should go to the dead-letter topic.
class LocationMessage
  class Invalid < StandardError; end

  attr_reader :shipment, :attributes

  def self.parse(raw)
    new(raw).tap(&:validate!)
  end

  def initialize(raw)
    @raw = raw
  end

  def validate!
    data = JSON.parse(@raw.to_s)
    raise Invalid, "payload must be a JSON object" unless data.is_a?(Hash)

    identifier = data["shipment_identifier"]
    raise Invalid, "shipment_identifier is required" unless identifier.is_a?(String) && identifier.present?

    @shipment = Shipment.find_by(shipment_identifier: identifier) or
      raise Invalid, "unknown shipment #{identifier}"

    @attributes = {
      latitude: number!(data, "latitude", -90..90),
      longitude: number!(data, "longitude", -180..180),
      recorded_at: Time.at(integer!(data, "recorded_at") / 1000.0).utc,
      address: data["address"],
      speed: data["speed"].nil? ? nil : number!(data, "speed", 0..Float::INFINITY)
    }
    self
  rescue JSON::ParserError => e
    raise Invalid, "malformed JSON: #{e.message.lines.first.strip}"
  end

  private

  def number!(data, key, range)
    value = data[key]
    raise Invalid, "#{key} must be a number" unless value.is_a?(Numeric)
    raise Invalid, "#{key} out of range" unless range.cover?(value)

    value
  end

  def integer!(data, key)
    value = data[key]
    raise Invalid, "#{key} must be epoch milliseconds (integer)" unless value.is_a?(Integer) && value.positive?

    value
  end
end
