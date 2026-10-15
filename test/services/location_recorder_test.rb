require "test_helper"

class LocationRecorderTest < ActiveSupport::TestCase
  setup do
    @shipment = create_shipment(shipment_identifier: "ING-1")
    @t0 = Time.utc(2026, 10, 15, 8, 0)
  end

  def ingest(lng, minutes, **extra)
    LocationRecorder.record(shipment: @shipment, latitude: 0, longitude: lng, recorded_at: @t0 + minutes.minutes, **extra)
  end

  test "creates the location" do
    assert_difference -> { ShipmentLocation.count }, 1 do
      ingest(0.0001, 0, address: "Dock", speed: 5)
    end
  end

  test "first point at source records no status change" do
    ingest(0.0001, 0)
    assert_empty @shipment.status_histories
    assert_equal "prepared", @shipment.reload.current_status
  end

  test "moving away creates history and updates the shipment" do
    ingest(0.03, 1, address: "Road")
    history = @shipment.status_histories.last
    assert_equal "in_transit", history.status
    assert_equal "Road", history.address
    assert_equal @t0 + 1.minute, history.changed_at
    assert_equal "in_transit", @shipment.reload.current_status
  end

  test "walks through the full journey" do
    ingest(0.0001, 0)
    ingest(0.012, 1)
    ingest(0.5, 2)
    ingest(0.985, 3)
    ingest(0.999, 4)
    assert_equal %w[picked_up in_transit out_for_delivery delivered], @shipment.status_histories.map(&:status)
    assert_equal "delivered", @shipment.reload.current_status
  end

  test "a replayed point is ignored" do
    ingest(0.02, 1)
    assert_no_difference [ "ShipmentLocation.count", "ShipmentStatusHistory.count" ] do
      assert_nil ingest(0.02, 1)
    end
  end

  test "an older point arriving late is stored but does not regress the status" do
    ingest(0.5, 5)
    ingest(0.0001, 1)

    assert_equal 2, @shipment.locations.count
    assert_equal [ "in_transit" ], @shipment.status_histories.map(&:status)
    assert_equal "in_transit", @shipment.reload.current_status
  end

  test "invalid point raises and changes nothing" do
    assert_raises(ActiveRecord::RecordInvalid) { ingest(500, 1) }
    assert_equal 0, ShipmentLocation.count
  end
end
