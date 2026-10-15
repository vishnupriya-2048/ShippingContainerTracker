require "test_helper"

class StatusDeciderTest < ActiveSupport::TestCase
  # Source and destination lie on the equator, 1 degree of longitude (~111 km) apart.
  DEGREES_PER_METRE = 1 / 111_195.0

  setup do
    @shipment = Shipment.new(
      shipment_identifier: "GEO-1", weight: 1, height: 1,
      source_address: "A", destination_address: "B",
      source_latitude: 0, source_longitude: 0,
      destination_latitude: 0, destination_longitude: 1.0
    )
  end

  def at_source(metres) = [ 0, metres * DEGREES_PER_METRE ]
  def at_destination(metres) = [ 0, 1.0 - metres * DEGREES_PER_METRE ]

  def decide(point) = StatusDecider.new_status_for(@shipment, *point)

  test "near source keeps prepared (nothing to change)" do
    assert_nil decide(at_source(100))
  end

  test "1 km from source is picked_up" do
    assert_equal "picked_up", decide(at_source(1_100))
  end

  test "between 500 m and 1 km from source matches no rule" do
    assert_nil decide(at_source(700))
  end

  test "3 km from source is in_transit" do
    @shipment.current_status = "picked_up"
    assert_equal "in_transit", decide(at_source(3_100))
  end

  test "within 2 km of destination is out_for_delivery" do
    @shipment.current_status = "in_transit"
    assert_equal "out_for_delivery", decide(at_destination(1_900))
  end

  test "within 500 m of destination is delivered" do
    @shipment.current_status = "out_for_delivery"
    assert_equal "delivered", decide(at_destination(400))
  end

  test "statuses can be skipped" do
    assert_equal "in_transit", decide(at_source(5_000))
  end

  test "never regresses" do
    @shipment.current_status = "in_transit"
    assert_nil decide(at_source(1_100))
    assert_nil decide(at_source(100))
  end

  test "delivered is final" do
    @shipment.current_status = "delivered"
    assert_nil decide(at_destination(1_900))
    assert_nil decide(at_source(5_000))
  end

  test "exception is never changed by the geofence" do
    @shipment.current_status = "exception"
    assert_nil decide(at_destination(100))
  end
end
