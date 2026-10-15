require "test_helper"

class HaversineTest < ActiveSupport::TestCase
  test "same point is zero" do
    assert_in_delta 0, Haversine.meters_between(12.9716, 77.5946, 12.9716, 77.5946), 0.001
  end

  test "Bangalore to Chennai is about 290 km" do
    km = Haversine.meters_between(12.9716, 77.5946, 13.0827, 80.2707) / 1000
    assert_in_delta 290, km, 5
  end

  test "one degree of latitude is about 111.2 km" do
    assert_in_delta 111_195, Haversine.meters_between(0, 0, 1, 0), 100
  end

  test "is symmetric" do
    a = Haversine.meters_between(41.8781, -87.6298, 33.749, -84.388)
    b = Haversine.meters_between(33.749, -84.388, 41.8781, -87.6298)
    assert_in_delta a, b, 0.001
  end
end
