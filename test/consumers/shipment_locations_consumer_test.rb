require "test_helper"

class ShipmentLocationsConsumerTest < ActiveSupport::TestCase
  FakeMessage = Struct.new(:raw_payload, :key, :partition, :offset)
  class FakeProducer
    attr_reader :sent
    def initialize = @sent = []
    def produce_sync(**message) = @sent << message
  end

  setup do
    @shipment = create_shipment(shipment_identifier: "KAF-1")
    @producer = FakeProducer.new
  end

  def consume(*payloads)
    consumer = ShipmentLocationsConsumer.new
    consumer.producer = @producer
    consumer.messages = payloads.each_with_index.map { |p, i| FakeMessage.new(p.is_a?(String) ? p : p.to_json, "KAF-1", 0, i) }
    consumer.consume
  end

  def point(**overrides)
    { shipment_identifier: "KAF-1", latitude: 0, longitude: 0.5, recorded_at: 1_729_781_200_000, speed: 40.5 }.merge(overrides)
  end

  test "valid message creates the location and applies the geofence" do
    consume(point(longitude: 0.5))

    location = @shipment.locations.sole
    assert_equal Time.at(1_729_781_200).utc, location.recorded_at
    assert_equal "in_transit", @shipment.reload.current_status
    assert_empty @producer.sent
  end

  test "replayed message does not duplicate" do
    consume(point, point)
    assert_equal 1, @shipment.locations.count
    assert_empty @producer.sent
  end

  test "bad messages go to the dead-letter topic with the reason and good ones still process" do
    consume("not json", point(shipment_identifier: "NOPE"), point(latitude: 123),
            point(recorded_at: "yesterday"), point(recorded_at: 1_729_781_300_000))

    assert_equal 1, @shipment.locations.count
    assert_equal 4, @producer.sent.size
    assert_equal [ "shipment_locations_dlq" ], @producer.sent.map { |m| m[:topic] }.uniq
    assert_equal [ "KAF-1" ], @producer.sent.map { |m| m[:key] }.uniq
    assert_match(/malformed JSON/, @producer.sent[0][:headers]["error"])
    assert_match(/unknown shipment NOPE/, @producer.sent[1][:headers]["error"])
    assert_match(/Latitude/, @producer.sent[2][:headers]["error"])
    assert_equal point(latitude: 123).to_json, @producer.sent[2][:payload]
  end
end
