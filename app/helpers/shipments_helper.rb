module ShipmentsHelper
  # Data handed to the Stimulus map controller: one entry per shipment that has a location.
  def map_markers_for(shipments)
    shipments.filter_map do |shipment|
      location = shipment.latest_location
      next unless location

      {
        id: shipment.id,
        identifier: shipment.shipment_identifier,
        status: status_label(shipment.current_status),
        color: status_style(shipment.current_status)[:color],
        lat: location.latitude,
        lng: location.longitude,
        address: location.address,
        recordedAt: location.recorded_at.iso8601
      }
    end
  end

  # Numbers for the dashboard tiles. "En route" covers every status between
  # pickup and delivery.
  def status_summary(shipments)
    counts = shipments.group_by(&:current_status).transform_values(&:size)
    [
      [ "Total", shipments.size, "text-slate-900" ],
      [ "En route", counts.values_at("picked_up", "in_transit", "out_for_delivery").compact.sum, "text-indigo-600" ],
      [ "Delivered", counts.fetch("delivered", 0), "text-emerald-600" ],
      [ "Exceptions", counts.fetch("exception", 0), "text-red-600" ]
    ]
  end

  # Data handed to the Stimulus trail controller on the detail page.
  def trail_data_for(shipment, locations, status_histories)
    current = locations.last

    {
      arrived: shipment.delivered?,
      points: locations.map { |l| { lat: l.latitude, lng: l.longitude, recordedAt: l.recorded_at.iso8601, address: l.address } },
      statuses: status_histories.map do |h|
        {
          id: h.id,
          lat: h.latitude,
          lng: h.longitude,
          status: status_label(h.status),
          color: status_style(h.status)[:color],
          glyph: status_style(h.status)[:glyph],
          address: h.address,
          notes: h.notes,
          changedAt: h.changed_at.iso8601
        }
      end,
      current: current.nil? ? {} : {
        lat: current.latitude,
        lng: current.longitude,
        color: status_style(shipment.current_status)[:color],
        status: status_label(shipment.current_status),
        address: current.address,
        recordedAt: current.recorded_at.iso8601
      },
      source: { lat: shipment.source_latitude, lng: shipment.source_longitude, address: shipment.source_address },
      destination: { lat: shipment.destination_latitude, lng: shipment.destination_longitude, address: shipment.destination_address }
    }
  end
end
