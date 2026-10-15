class AddConstraintsAndHistoryIndex < ActiveRecord::Migration[8.1]
  STATUSES = %w[prepared picked_up in_transit out_for_delivery delivered exception].freeze
  STATUS_LIST = STATUSES.map { |s| "'#{s}'" }.join(", ")

  def change
    add_check_constraint :shipments, "weight > 0 AND height > 0", name: "shipments_positive_size"
    add_check_constraint :shipments,
                         "source_latitude BETWEEN -90 AND 90 AND destination_latitude BETWEEN -90 AND 90",
                         name: "shipments_latitude_range"
    add_check_constraint :shipments,
                         "source_longitude BETWEEN -180 AND 180 AND destination_longitude BETWEEN -180 AND 180",
                         name: "shipments_longitude_range"
    add_check_constraint :shipments, "current_status IN (#{STATUS_LIST})", name: "shipments_known_status"

    add_check_constraint :shipment_locations,
                         "latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180",
                         name: "shipment_locations_coordinate_range"
    add_check_constraint :shipment_status_histories,
                         "latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180",
                         name: "shipment_status_histories_coordinate_range"
    add_check_constraint :shipment_status_histories, "status IN (#{STATUS_LIST})", name: "shipment_status_histories_known_status"

    # The composite unique index already serves lookups by shipment_id alone.
    remove_index :shipment_locations, column: :shipment_id

    add_index :shipment_status_histories, %i[shipment_id changed_at]
    remove_index :shipment_status_histories, column: :shipment_id
  end
end
