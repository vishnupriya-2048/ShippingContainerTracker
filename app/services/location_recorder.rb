# Stores one validated location and applies any resulting status change, all in
# one transaction. Replays are ignored: a point with the same shipment and
# recorded_at is skipped (enforced by a unique index, so it is safe even when
# two consumers race).
#
# Returns the ShipmentLocation, or nil if it was a duplicate.
class LocationRecorder
  def self.record(shipment:, **attributes)
    new(shipment, attributes).run
  end

  def initialize(shipment, attributes)
    @shipment = shipment
    @attributes = attributes
  end

  def run
    Shipment.transaction do
      @shipment.lock!
      location = @shipment.locations.create!(@attributes)
      apply_status_change(location)
      location
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  private

  def apply_status_change(location)
    new_status = StatusDecider.new_status_for(@shipment, location.latitude, location.longitude)
    return unless new_status

    @shipment.status_histories.create!(
      status: new_status, latitude: location.latitude, longitude: location.longitude,
      address: location.address, changed_at: location.recorded_at
    )
    @shipment.update!(current_status: new_status)
  end
end
