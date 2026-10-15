require "json"

# Builds GPS trails for seed shipments: loads sample route files or interpolates a
# path between two points, then adds timestamps and speeds derived from distance.
class TrailBuilder
  EARTH_RADIUS_KM = 6371.0
  STATIONARY_KM = 0.05      # moves smaller than this are GPS jitter, not travel
  STATIONARY_STEP_S = 60
  SPEED_RANGE_KMH = (50.0..90.0)

  def initialize(seed:)
    @rng = Random.new(seed)
  end

  # Points are hashes with :latitude, :longitude, :address.
  def from_file(path)
    JSON.parse(File.read(path)).map do |p|
      { latitude: p["latitude"], longitude: p["longitude"], address: p["address"] }
    end
  end

  # Straight-ish path with a few stationary points at each end, like the sample files.
  def interpolate(from, to, count: 60, dwell: 5)
    moving = count - 2 * dwell
    path = Array.new(moving) do |i|
      t = (i + 1).fdiv(moving + 1)
      {
        latitude: from[:latitude] + (to[:latitude] - from[:latitude]) * t + jitter,
        longitude: from[:longitude] + (to[:longitude] - from[:longitude]) * t + jitter,
        address: nil
      }
    end
    Array.new(dwell, from.slice(:latitude, :longitude, :address)) +
      path +
      Array.new(dwell, to.slice(:latitude, :longitude, :address))
  end

  # Returns rows ready for ShipmentLocation.insert_all, ending at `ends_at`.
  def timestamped(points, ends_at:)
    elapsed = 0.0
    rows = points.each_with_index.map do |point, i|
      speed = 0.0
      if i.positive?
        km = distance_km(points[i - 1], point)
        if km < STATIONARY_KM
          elapsed += STATIONARY_STEP_S
        else
          speed = @rng.rand(SPEED_RANGE_KMH).round(1)
          elapsed += km / speed * 3600
        end
      end
      point.merge(speed: speed, offset_s: elapsed)
    end
    start = ends_at - elapsed
    rows.map { |r| r.except(:offset_s).merge(recorded_at: start + r[:offset_s]) }
  end

  private

  def jitter = @rng.rand(-0.01..0.01)

  def distance_km(a, b)
    lat1, lat2 = [a[:latitude], b[:latitude]].map { |d| d * Math::PI / 180 }
    dlat = lat2 - lat1
    dlng = (b[:longitude] - a[:longitude]) * Math::PI / 180
    h = Math.sin(dlat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlng / 2)**2
    2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h))
  end
end
