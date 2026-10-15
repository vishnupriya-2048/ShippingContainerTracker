require "test_helper"

class ShipmentStatusHistoryTest < ActiveSupport::TestCase
  setup do
    @shipment = Shipment.create!(
      shipment_identifier: "DHL-12345", weight: 120.5, height: 80.0,
      source_address: "Peenya Industrial Area, Bangalore, Karnataka, India",
      destination_address: "Guindy, Chennai, Tamil Nadu, India",
      source_latitude: 13.0285, source_longitude: 77.5197,
      destination_latitude: 13.0067, destination_longitude: 80.2206
    )
  end

  def history_attributes(overrides = {})
    {
      shipment: @shipment, status: :picked_up, latitude: 13.0, longitude: 77.6,
      changed_at: Time.utc(2026, 10, 15, 9, 0)
    }.merge(overrides)
  end

  test "valid with required attributes only (address and notes are optional)" do
    history = ShipmentStatusHistory.new(history_attributes)
    assert history.valid?, history.errors.full_messages.to_sentence
  end

  test "valid with address and notes" do
    assert ShipmentStatusHistory.new(history_attributes(address: "Hosur Road, Bangalore", notes: "Left the depot")).valid?
  end

  test "requires status, latitude, longitude, changed_at and shipment" do
    %i[status latitude longitude changed_at shipment].each do |field|
      history = ShipmentStatusHistory.new(history_attributes(field => nil))
      assert_not history.valid?, "expected #{field} to be required"
      assert history.errors[field].any?, "expected an error on #{field}"
    end
  end

  test "status enum has the same six statuses as Shipment" do
    assert_equal Shipment.current_statuses.keys, ShipmentStatusHistory.statuses.keys
  end

  test "status rejects unknown values" do
    assert_raises(ArgumentError) { ShipmentStatusHistory.new(status: "teleported") }
  end

  test "status is stored as a string" do
    history = ShipmentStatusHistory.create!(history_attributes(status: :out_for_delivery))
    raw = ShipmentStatusHistory.connection.select_value("SELECT status FROM shipment_status_histories WHERE id = #{history.id}")
    assert_equal "out_for_delivery", raw
  end

  test "latitude and longitude ranges are enforced" do
    assert_not ShipmentStatusHistory.new(history_attributes(latitude: 91)).valid?
    assert_not ShipmentStatusHistory.new(history_attributes(longitude: -181)).valid?
  end

  test "belongs to a shipment" do
    history = ShipmentStatusHistory.create!(history_attributes)
    assert_equal @shipment, history.shipment
  end

  test "chronological scope orders oldest first" do
    late = ShipmentStatusHistory.create!(history_attributes(status: :in_transit, changed_at: Time.utc(2026, 10, 15, 12, 0)))
    early = ShipmentStatusHistory.create!(history_attributes(status: :prepared, changed_at: Time.utc(2026, 10, 15, 7, 0)))
    middle = ShipmentStatusHistory.create!(history_attributes(status: :picked_up, changed_at: Time.utc(2026, 10, 15, 9, 0)))
    assert_equal [ early, middle, late ], ShipmentStatusHistory.chronological.to_a
  end

  test "has a foreign key to shipments" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:shipment_status_histories)
    assert foreign_keys.any? { |fk| fk.to_table == "shipments" }
  end
end
