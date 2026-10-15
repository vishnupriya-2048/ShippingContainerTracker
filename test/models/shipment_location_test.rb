require "test_helper"

class ShipmentLocationTest < ActiveSupport::TestCase
  setup do
    @shipment = Shipment.create!(
      shipment_identifier: "DHL-12345", weight: 120.5, height: 80.0,
      source_address: "Peenya Industrial Area, Bangalore, Karnataka, India",
      destination_address: "Guindy, Chennai, Tamil Nadu, India",
      source_latitude: 13.0285, source_longitude: 77.5197,
      destination_latitude: 13.0067, destination_longitude: 80.2206
    )
  end

  def location_attributes(overrides = {})
    { shipment: @shipment, latitude: 12.9716, longitude: 77.5946, recorded_at: Time.utc(2026, 10, 15, 8, 0) }.merge(overrides)
  end

  test "valid with required attributes only (address and speed are optional)" do
    location = ShipmentLocation.new(location_attributes)
    assert location.valid?, location.errors.full_messages.to_sentence
  end

  test "valid with address and speed" do
    assert ShipmentLocation.new(location_attributes(address: "MG Road, Bangalore", speed: 45.5)).valid?
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

  test "belongs to a shipment" do
    location = ShipmentLocation.create!(location_attributes)
    assert_equal @shipment, location.shipment
  end

  test "recorded_at keeps its value" do
    time = Time.utc(2026, 10, 15, 8, 10)
    location = ShipmentLocation.create!(location_attributes(recorded_at: time))
    assert_equal time, location.reload.recorded_at
  end

  test "chronological scope orders oldest first" do
    late = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 20)))
    early = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 0)))
    middle = ShipmentLocation.create!(location_attributes(recorded_at: Time.utc(2026, 10, 15, 8, 10)))
    assert_equal [ early, middle, late ], ShipmentLocation.chronological.to_a
  end

  test "has a composite index on [shipment_id, recorded_at]" do
    indexes = ActiveRecord::Base.connection.indexes(:shipment_locations)
    assert indexes.any? { |i| i.columns == %w[shipment_id recorded_at] }, "missing [shipment_id, recorded_at] index"
  end

  test "has a foreign key to shipments" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:shipment_locations)
    assert foreign_keys.any? { |fk| fk.to_table == "shipments" }
  end
end
