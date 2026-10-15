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

  # Data handed to the Stimulus trail controller on the detail page.
  def trail_data_for(shipment, locations)
    current = locations.last

    {
      arrived: shipment.delivered?,
      path: locations.map { |l| { lat: l.latitude, lng: l.longitude } },
      current: current.nil? ? {} : {
        lat: current.latitude,
        lng: current.longitude,
        color: status_style(shipment.current_status)[:hex],
        status: shipment.current_status.humanize,
        address: current.address,
        recordedAt: current.recorded_at.iso8601
      },
      source: { lat: shipment.source_latitude, lng: shipment.source_longitude, address: shipment.source_address },
      destination: { lat: shipment.destination_latitude, lng: shipment.destination_longitude, address: shipment.destination_address }
    }
  end
end
