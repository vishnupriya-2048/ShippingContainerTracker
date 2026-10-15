require "test_helper"

class SeedDataTest < ActiveSupport::TestCase
  # Fixtures are not used; start from an empty DB so counts are exact.
  self.use_transactional_tests = true
  fixtures []

  def load_seeds = load Rails.root.join("db/seeds.rb"), true

  setup do
    ShipmentLocation.delete_all
    ShipmentStatusHistory.delete_all
    Shipment.delete_all
  end

  test "seeds create 5 shipments each with at least 50 chronological locations" do
    load_seeds

    assert_equal 5, Shipment.count
    Shipment.find_each do |shipment|
      locations = shipment.locations.to_a
      assert_operator locations.size, :>=, 50, "#{shipment.shipment_identifier} has #{locations.size} locations"
      assert_equal locations.sort_by(&:recorded_at), locations
      assert locations.all? { |l| l.speed }, "#{shipment.shipment_identifier} has points without speed"
    end
  end

  test "shipment source and destination match the first and last trail points" do
    load_seeds

    assert_equal 5, Shipment.count
    Shipment.find_each do |s|
      assert_equal [s.source_latitude, s.source_longitude], [s.locations.first.latitude, s.locations.first.longitude]
      assert_equal [s.destination_latitude, s.destination_longitude], [s.locations.last.latitude, s.locations.last.longitude]
    end
  end

  test "seeds leave status at prepared with no status history" do
    load_seeds

    assert_equal 5, Shipment.count
    assert Shipment.all.all?(&:prepared?)
    assert_equal 0, ShipmentStatusHistory.count
  end

  test "running seeds twice creates no duplicates" do
    load_seeds
    counts = [Shipment.count, ShipmentLocation.count]
    assert_equal [5, true], [counts[0], counts[1] >= 250]
    load_seeds

    assert_equal counts, [Shipment.count, ShipmentLocation.count]
  end
end
