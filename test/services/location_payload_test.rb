require "test_helper"

class LocationPayloadTest < ActiveSupport::TestCase
  setup { @shipment = create_shipment(shipment_identifier: "PAY-1") }

  def parse(**overrides)
    LocationPayload.parse({ shipment_identifier: "PAY-1", latitude: 1.5, longitude: 2.5, recorded_at: 1_729_781_200_123 }.merge(overrides).to_json)
  end

  def assert_invalid(message, **overrides)
    error = assert_raises(LocationPayload::Invalid) { parse(**overrides) }
    assert_match message, error.message
  end

  test "parses a valid payload with optional fields" do
    payload = parse(address: "MG Road", speed: 45.5)

    assert_equal @shipment, payload.shipment
    assert_equal({ latitude: 1.5, longitude: 2.5, recorded_at: Time.at(1_729_781_200, 123, :millisecond).utc, address: "MG Road", speed: 45.5 }, payload.attributes)
  end

  test "keeps millisecond precision" do
    assert_equal 123, parse.attributes[:recorded_at].usec / 1000
  end

  test "address and speed are optional" do
    assert_nil parse.attributes[:address]
    assert_nil parse.attributes[:speed]
  end

  test "rejects payloads that are not a JSON object" do
    assert_raises(LocationPayload::Invalid) { LocationPayload.parse("[1, 2]") }
    assert_raises(LocationPayload::Invalid) { LocationPayload.parse(nil) }
  end

  test "rejects a missing or unknown shipment" do
    assert_invalid(/shipment_identifier is required/, shipment_identifier: nil)
    assert_invalid(/unknown shipment NOPE/, shipment_identifier: "NOPE")
  end

  test "rejects non-numeric coordinates" do
    assert_invalid(/latitude must be a number/, latitude: "1.5")
    assert_invalid(/longitude must be a number/, longitude: nil)
  end

  test "rejects recorded_at that is not epoch milliseconds in range" do
    [ 0, -5, 1.5, "1729781200000", 10**20 ].each do |value|
      assert_invalid(/recorded_at must be epoch milliseconds/, recorded_at: value)
    end
  end

  test "rejects an address that is not a string and a speed that is not a number" do
    assert_invalid(/address must be a string/, address: { street: "x" })
    assert_invalid(/speed must be a number/, speed: "fast")
  end

  test "leaves value ranges to the model" do
    assert_equal 123, parse(latitude: 123).attributes[:latitude]
  end
end
