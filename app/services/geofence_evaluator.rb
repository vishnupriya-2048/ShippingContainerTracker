# Decides whether a new GPS point moves a shipment to a new status.
#
# Rules (distances in meters), checked in this order, first match wins:
#   <= 500 from destination  -> delivered
#   <= 2000 from destination -> out_for_delivery
#   >= 3000 from source      -> in_transit
#   >= 1000 from source      -> picked_up
# Destination rules come first so a short route can still finish. Between 0 and
# 1 km from the source no rule matches, so the status is left alone. `prepared`
# is the starting status, so there is no rule for it: a shipment is prepared until
# it first moves 1 km from the source.
#
# Decisions:
# - No regression: a status is only returned if it ranks higher than the current
#   one (prepared < picked_up < in_transit < out_for_delivery < delivered). A
#   GPS point drifting back near the source never undoes progress, and
#   `delivered` is final.
# - `exception` is a manual override: once set, the geofence never changes it.
# - Statuses may be skipped (a sparse trail can jump straight to in_transit).
class GeofenceEvaluator
  STATUS_ORDER = %w[prepared picked_up in_transit out_for_delivery delivered].freeze

  def self.evaluate(shipment, latitude, longitude)
    new(shipment, latitude, longitude).call
  end

  def initialize(shipment, latitude, longitude)
    @shipment = shipment
    @latitude = latitude
    @longitude = longitude
  end

  # Returns the new status string, or nil when nothing should change.
  def call
    current = @shipment.current_status
    return nil unless STATUS_ORDER.include?(current)

    candidate = status_for_position
    return nil unless candidate && STATUS_ORDER.index(candidate) > STATUS_ORDER.index(current)

    candidate
  end

  private

  def status_for_position
    from_destination = meters_to(@shipment.destination_latitude, @shipment.destination_longitude)
    from_source = meters_to(@shipment.source_latitude, @shipment.source_longitude)

    if from_destination <= 500 then "delivered"
    elsif from_destination <= 2_000 then "out_for_delivery"
    elsif from_source >= 3_000 then "in_transit"
    elsif from_source >= 1_000 then "picked_up"
    end
  end

  def meters_to(lat, lng)
    Haversine.meters_between(@latitude, @longitude, lat, lng)
  end
end
