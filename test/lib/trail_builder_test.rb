require "test_helper"

class TrailBuilderTest < ActiveSupport::TestCase
  FROM = { latitude: 41.8781, longitude: -87.6298, address: "Chicago" }.freeze
  TO = { latitude: 33.7490, longitude: -84.3880, address: "Atlanta" }.freeze

  setup { @builder = TrailBuilder.new(seed: 1) }

  test "interpolate returns the requested number of points starting at source and ending at destination" do
    points = @builder.interpolate(FROM, TO, count: 60)

    assert_equal 60, points.size
    assert_equal [ FROM[:latitude], FROM[:longitude] ], points.first.values_at(:latitude, :longitude)
    assert_equal [ TO[:latitude], TO[:longitude] ], points.last.values_at(:latitude, :longitude)
  end

  test "timestamped orders points chronologically and ends at ends_at" do
    ends_at = Time.utc(2026, 10, 15, 12)
    rows = @builder.timestamped(@builder.interpolate(FROM, TO), ends_at: ends_at)
    times = rows.map { |r| r[:recorded_at] }

    assert_equal times.sort, times
    assert_in_delta ends_at.to_f, times.last.to_f, 1
  end

  test "stationary points get speed 0 and moving points a realistic speed" do
    rows = @builder.timestamped(@builder.interpolate(FROM, TO, dwell: 5), ends_at: Time.current)

    assert_equal 0.0, rows.first[:speed]
    assert_equal 0.0, rows.last[:speed]
    moving = rows[6...-5]
    assert moving.all? { |r| r[:speed].between?(50, 90) }
  end

  test "same seed gives the same trail" do
    ends_at = Time.utc(2026, 10, 15)
    a = TrailBuilder.new(seed: 7).timestamped(TrailBuilder.new(seed: 7).interpolate(FROM, TO), ends_at: ends_at)
    b = TrailBuilder.new(seed: 7).timestamped(TrailBuilder.new(seed: 7).interpolate(FROM, TO), ends_at: ends_at)

    assert_equal a, b
  end
end
