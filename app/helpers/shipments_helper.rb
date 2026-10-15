module ShipmentsHelper
  # Data handed to the Stimulus map controller: one entry per shipment that has a location.
  def map_markers_for(shipments)
    shipments.filter_map do |shipment|
      location = shipment.latest_location
      next unless location

      {
        id: shipment.id,
        identifier: shipment.shipment_identifier,
        status: shipment.current_status.humanize,
        color: status_style(shipment.current_status)[:hex],
        lat: location.latitude,
        lng: location.longitude,
        address: location.address,
        recordedAt: location.recorded_at.iso8601
      }
    end
  end

  def status_counts(shipments)
    shipments.group_by(&:current_status).transform_values(&:size)
  end
end
