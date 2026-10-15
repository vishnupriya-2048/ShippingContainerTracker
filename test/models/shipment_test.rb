require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  test "valid with all required attributes" do
    assert build_shipment.valid?
  end

  test "requires every field from the assignment table" do
    %i[shipment_identifier weight height source_address destination_address
       source_latitude source_longitude destination_latitude destination_longitude].each do |field|
      shipment = build_shipment(field => nil)
      assert_not shipment.valid?, "expected #{field} to be required"
      assert shipment.errors[field].any?, "expected an error on #{field}"
    end
  end

  test "shipment_identifier must be unique at the model level" do
    create_shipment
    duplicate = build_shipment
    assert_not duplicate.valid?
    assert duplicate.errors[:shipment_identifier].any?
  end

  test "shipment_identifier must be unique at the database level" do
    create_shipment
    assert_raises(ActiveRecord::RecordNotUnique) { build_shipment.save!(validate: false) }
  end

  test "weight and height must be numeric and positive" do
    [ "heavy", 0, -1 ].each do |value|
      assert_not build_shipment(weight: value).valid?, "weight #{value.inspect}"
      assert_not build_shipment(height: value).valid?, "height #{value.inspect}"
    end
  end

  test "the database also rejects out-of-range values" do
    assert_raises(ActiveRecord::StatementInvalid) { build_shipment(weight: 0).save!(validate: false) }
    assert_raises(ActiveRecord::StatementInvalid) { build_shipment(source_latitude: 91).save!(validate: false) }
    assert_raises(ActiveRecord::StatementInvalid) { build_shipment(destination_longitude: 181).save!(validate: false) }
  end

  test "latitude must be within -90..90" do
    %i[source_latitude destination_latitude].each do |field|
      assert_not build_shipment(field => 90.1).valid?, "#{field} 90.1"
      assert_not build_shipment(field => -90.1).valid?, "#{field} -90.1"
      assert build_shipment(field => 90).valid?, "#{field} 90"
      assert build_shipment(field => -90).valid?, "#{field} -90"
    end
  end

  test "longitude must be within -180..180" do
    %i[source_longitude destination_longitude].each do |field|
      assert_not build_shipment(field => 180.1).valid?, "#{field} 180.1"
      assert_not build_shipment(field => -180.1).valid?, "#{field} -180.1"
      assert build_shipment(field => 180).valid?, "#{field} 180"
      assert build_shipment(field => -180).valid?, "#{field} -180"
    end
  end

  test "current_status defaults to prepared" do
    assert_equal "prepared", build_shipment.current_status
  end

  test "current_status enum has exactly the six assignment statuses" do
    expected = %w[prepared picked_up in_transit out_for_delivery delivered exception]
    assert_equal expected, Shipment.current_statuses.keys
  end

  def add_location(shipment, minutes)
    shipment.locations.create!(latitude: 12.97, longitude: 77.59, recorded_at: Time.utc(2026, 10, 15, 8, 0) + minutes.minutes)
  end

  test "locations are returned oldest first regardless of insert order" do
    shipment = create_shipment
    late = add_location(shipment, 20)
    early = add_location(shipment, 0)
    middle = add_location(shipment, 10)
    assert_equal [ early, middle, late ], shipment.locations.to_a
  end

  test "status_histories are returned oldest first regardless of insert order" do
    shipment = create_shipment
    late = shipment.status_histories.create!(status: :in_transit, latitude: 13.0, longitude: 77.9, changed_at: Time.utc(2026, 10, 15, 12))
    early = shipment.status_histories.create!(status: :prepared, latitude: 13.0, longitude: 77.5, changed_at: Time.utc(2026, 10, 15, 7))
    assert_equal [ early, late ], shipment.status_histories.to_a
  end

  test "latest_location returns the location with the newest recorded_at" do
    shipment = create_shipment
    add_location(shipment, 10)
    newest = add_location(shipment, 30)
    add_location(shipment, 0)
    assert_equal newest, shipment.latest_location
  end

  test "latest_location is nil when the shipment has no locations" do
    assert_nil create_shipment.latest_location
  end

  test "destroying a shipment destroys its locations and status histories" do
    shipment = create_shipment
    add_location(shipment, 0)
    shipment.status_histories.create!(status: :prepared, latitude: 13.0, longitude: 77.5, changed_at: Time.utc(2026, 10, 15, 7))
    assert_difference [ "ShipmentLocation.count", "ShipmentStatusHistory.count" ], -1 do
      shipment.destroy!
    end
  end

  test "one shipment's records do not leak into another" do
    first = create_shipment
    second = create_shipment(shipment_identifier: "OTHER-1")
    add_location(first, 0)
    assert_empty second.locations
    assert_nil second.latest_location
  end

  test "mark_exception records the change at the latest location" do
    shipment = create_shipment
    shipment.locations.create!(latitude: 0.2, longitude: 0.3, recorded_at: 1.hour.ago, address: "Hosur Road")

    assert shipment.mark_exception

    history = shipment.status_histories.sole
    assert_equal [ "exception", 0.2, 0.3, "Hosur Road" ], [ history.status, history.latitude, history.longitude, history.address ]
    assert_equal "exception", shipment.reload.current_status
  end

  test "mark_exception falls back to the source when nothing was reported" do
    shipment = create_shipment(source_latitude: 5.0, source_longitude: 6.0, source_address: "Depot")

    assert shipment.mark_exception

    history = shipment.status_histories.sole
    assert_equal [ 5.0, 6.0, "Depot" ], [ history.latitude, history.longitude, history.address ]
  end

  test "mark_exception is refused for delivered and already-exception shipments" do
    %w[delivered exception].each do |status|
      shipment = create_shipment(shipment_identifier: "S-#{status}", current_status: status)
      assert_not shipment.can_mark_exception?
      assert_not shipment.mark_exception
      assert_empty shipment.status_histories
    end
  end
end
