class MakeShipmentLocationsIndexUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :shipment_locations, %i[shipment_id recorded_at]
    add_index :shipment_locations, %i[shipment_id recorded_at], unique: true
  end
end
