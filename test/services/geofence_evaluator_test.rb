require "test_helper"

class GeofenceEvaluatorTest < ActiveSupport::TestCase
  # Source and destination lie on the equator, 1 degree of longitude (~111 km) apart.
  DEGREES_PER_METER = 1 / 111_195.0

  setup { @shipment = build_shipment }

  def at_source(meters) = [ 0, meters * DEGREES_PER_METER ]
  def at_destination(meters) = [ 0, 1.0 - meters * DEGREES_PER_METER ]

  def evaluate(point, from: "prepared")
    @shipment.current_status = from
    GeofenceEvaluator.evaluate(@shipment, *point)
  end

  test "near the source nothing changes: prepared is the starting status" do
    assert_nil evaluate(at_source(100))
  end

  test "1 km from source is picked_up" do
    assert_equal "picked_up", evaluate(at_source(1_010))
  end

  test "between 0 and 1 km from source matches no rule" do
    assert_nil evaluate(at_source(990))
  end

  test "3 km from source is in_transit" do
    assert_equal "in_transit", evaluate(at_source(3_010), from: "picked_up")
    assert_equal "picked_up", evaluate(at_source(2_990))
  end

  test "within 2 km of destination is out_for_delivery" do
    assert_equal "out_for_delivery", evaluate(at_destination(1_990), from: "in_transit")
    assert_equal "in_transit", evaluate(at_destination(2_010), from: "picked_up")
  end

  test "within 500 m of destination is delivered" do
    assert_equal "delivered", evaluate(at_destination(490), from: "out_for_delivery")
    assert_equal "out_for_delivery", evaluate(at_destination(510), from: "in_transit")
  end

  test "destination rules win on a short route where both zones overlap" do
    @shipment.destination_longitude = 0.02 # ~2.2 km from the source
    assert_equal "delivered", evaluate([ 0, 0.0199 ])
  end

  test "statuses can be skipped" do
    assert_equal "in_transit", evaluate(at_source(5_000))
  end

  test "never regresses" do
    assert_nil evaluate(at_source(1_100), from: "in_transit")
    assert_nil evaluate(at_source(100), from: "in_transit")
  end

  test "delivered is final" do
    assert_nil evaluate(at_destination(1_900), from: "delivered")
    assert_nil evaluate(at_source(5_000), from: "delivered")
  end

  test "exception is never changed by the geofence" do
    assert_nil evaluate(at_destination(100), from: "exception")
  end
end
