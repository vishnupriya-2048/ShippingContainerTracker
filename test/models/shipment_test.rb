require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      shipment_identifier: "DHL-12345",
      weight: 120.5,
      height: 80.0,
      source_address: "Peenya Industrial Area, Bangalore, Karnataka, India",
      destination_address: "Guindy, Chennai, Tamil Nadu, India",
      source_latitude: 13.0285,
      source_longitude: 77.5197,
      destination_latitude: 13.0067,
      destination_longitude: 80.2206
    }.merge(overrides)
  end

  test "valid with all required attributes" do
    assert Shipment.new(valid_attributes).valid?
  end

  test "requires every field from the assignment table" do
    %i[shipment_identifier weight height source_address destination_address
       source_latitude source_longitude destination_latitude destination_longitude].each do |field|
      shipment = Shipment.new(valid_attributes(field => nil))
      assert_not shipment.valid?, "expected #{field} to be required"
      assert shipment.errors[field].any?, "expected an error on #{field}"
    end
  end

  test "shipment_identifier must be unique at the model level" do
    Shipment.create!(valid_attributes)
    duplicate = Shipment.new(valid_attributes)
    assert_not duplicate.valid?
    assert duplicate.errors[:shipment_identifier].any?
  end

  test "shipment_identifier must be unique at the database level" do
    Shipment.create!(valid_attributes)
    duplicate = Shipment.new(valid_attributes)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "weight and height must be numeric" do
    assert_not Shipment.new(valid_attributes(weight: "heavy")).valid?
    assert_not Shipment.new(valid_attributes(height: "tall")).valid?
  end

  test "latitude must be within -90..90" do
    %i[source_latitude destination_latitude].each do |field|
      assert_not Shipment.new(valid_attributes(field => 90.1)).valid?, "#{field} 90.1"
      assert_not Shipment.new(valid_attributes(field => -90.1)).valid?, "#{field} -90.1"
      assert Shipment.new(valid_attributes(field => 90)).valid?, "#{field} 90"
      assert Shipment.new(valid_attributes(field => -90)).valid?, "#{field} -90"
    end
  end

  test "longitude must be within -180..180" do
    %i[source_longitude destination_longitude].each do |field|
      assert_not Shipment.new(valid_attributes(field => 180.1)).valid?, "#{field} 180.1"
      assert_not Shipment.new(valid_attributes(field => -180.1)).valid?, "#{field} -180.1"
      assert Shipment.new(valid_attributes(field => 180)).valid?, "#{field} 180"
      assert Shipment.new(valid_attributes(field => -180)).valid?, "#{field} -180"
    end
  end

  test "current_status defaults to prepared" do
    assert_equal "prepared", Shipment.new(valid_attributes).current_status
  end

  test "current_status enum has exactly the six assignment statuses" do
    expected = %w[prepared picked_up in_transit out_for_delivery delivered exception]
    assert_equal expected, Shipment.current_statuses.keys
  end

  test "enum provides predicate and rejects unknown values" do
    shipment = Shipment.create!(valid_attributes(current_status: :in_transit))
    assert shipment.in_transit?
    assert_raises(ArgumentError) { Shipment.new(current_status: "teleported") }
  end

  test "current_status is stored as a string, not an integer" do
    shipment = Shipment.create!(valid_attributes(current_status: :delivered))
    raw = Shipment.connection.select_value("SELECT current_status FROM shipments WHERE id = #{shipment.id}")
    assert_equal "delivered", raw
  end

  # --- Step 2: associations ---

  def add_location(shipment, minutes)
    shipment.locations.create!(latitude: 12.97, longitude: 77.59, recorded_at: Time.utc(2026, 10, 15, 8, 0) + minutes.minutes)
  end

  test "locations are returned oldest first regardless of insert order" do
    shipment = Shipment.create!(valid_attributes)
    late = add_location(shipment, 20)
    early = add_location(shipment, 0)
    middle = add_location(shipment, 10)
    assert_equal [ early, middle, late ], shipment.locations.to_a
  end

  test "status_histories are returned oldest first regardless of insert order" do
    shipment = Shipment.create!(valid_attributes)
    late = shipment.status_histories.create!(status: :in_transit, latitude: 13.0, longitude: 77.9, changed_at: Time.utc(2026, 10, 15, 12))
    early = shipment.status_histories.create!(status: :prepared, latitude: 13.0, longitude: 77.5, changed_at: Time.utc(2026, 10, 15, 7))
    assert_equal [ early, late ], shipment.status_histories.to_a
  end

  test "latest_location returns the location with the newest recorded_at" do
    shipment = Shipment.create!(valid_attributes)
    add_location(shipment, 10)
    newest = add_location(shipment, 30)
    add_location(shipment, 0)
    assert_equal newest, shipment.latest_location
  end

  test "latest_location is nil when the shipment has no locations" do
    assert_nil Shipment.create!(valid_attributes).latest_location
  end

  test "destroying a shipment destroys its locations and status histories" do
    shipment = Shipment.create!(valid_attributes)
    add_location(shipment, 0)
    shipment.status_histories.create!(status: :prepared, latitude: 13.0, longitude: 77.5, changed_at: Time.utc(2026, 10, 15, 7))
    assert_difference [ "ShipmentLocation.count", "ShipmentStatusHistory.count" ], -1 do
      shipment.destroy!
    end
  end

  test "one shipment's records do not leak into another" do
    first = Shipment.create!(valid_attributes)
    second = Shipment.create!(valid_attributes(shipment_identifier: "DHL-99999"))
    add_location(first, 0)
    assert_empty second.locations
    assert_nil second.latest_location
  end
end
