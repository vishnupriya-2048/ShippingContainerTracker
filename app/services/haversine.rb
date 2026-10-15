# Great-circle distance between two GPS points (the haversine formula).
class Haversine
  EARTH_RADIUS_M = 6_371_000.0

  # Distance in meters between two lat/lng points given in degrees.
  def self.meters_between(lat1, lng1, lat2, lng2)
    phi1 = to_radians(lat1)
    phi2 = to_radians(lat2)
    d_phi = to_radians(lat2 - lat1)
    d_lambda = to_radians(lng2 - lng1)

    a = Math.sin(d_phi / 2)**2 + Math.cos(phi1) * Math.cos(phi2) * Math.sin(d_lambda / 2)**2
    2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a))
  end

  def self.to_radians(degrees)
    degrees * Math::PI / 180
  end
  private_class_method :to_radians
end
