require "test_helper"

class ShipmentLocationTest < ActiveSupport::TestCase
  setup { @shipment = create_shipment }

  def location_attributes(overrides = {})
    { shipment: @shipment, latitude: 12.9716, longitude: 77.5946, recorded_at: Time.utc(2026, 10, 15, 8, 0) }.merge(overrides)
  end

  test "valid with required attributes only (address and speed are optional)" do
    location = ShipmentLocation.new(location_attributes)
    assert location.valid?, location.errors.full_messages.to_sentence
  end

  test "requires latitude, longitude, recorded_at and shipment" do
    %i[latitude longitude recorded_at shipment].each do |field|
      location = ShipmentLocation.new(location_attributes(field => nil))
      assert_not location.valid?, "expected #{field} to be required"
      assert location.errors[field].any?, "expected an error on #{field}"
    end
  end

  test "latitude must be within -90..90 and longitude within -180..180" do
    assert_not ShipmentLocation.new(location_attributes(latitude: 90.1)).valid?
    assert_not ShipmentLocation.new(location_attributes(latitude: -90.1)).valid?
    assert_not ShipmentLocation.new(location_attributes(longitude: 180.1)).valid?
    assert_not ShipmentLocation.new(location_attributes(longitude: -180.1)).valid?
  end

  test "speed must be numeric and not negative when present" do
    assert_not ShipmentLocation.new(location_attributes(speed: "fast")).valid?
    assert_not ShipmentLocation.new(location_attributes(speed: -1)).valid?
    assert ShipmentLocation.new(location_attributes(speed: 0)).valid?
  end

  test "a shipment cannot have two locations with the same recorded_at" do
    ShipmentLocation.create!(location_attributes)
    assert_raises(ActiveRecord::RecordNotUnique) { ShipmentLocation.create!(location_attributes) }
  end

  test "chronological scope orders oldest first" do
    late = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 20)))
    early = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 0)))
    middle = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 10)))
    assert_equal [ early, middle, late ], ShipmentLocation.chronological.to_a
  end
end
