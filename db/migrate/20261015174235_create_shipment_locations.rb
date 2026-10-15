class CreateShipmentLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_locations do |t|
      t.references :shipment, null: false, foreign_key: true
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.datetime :recorded_at, null: false
      t.string :address
      t.float :speed

      t.timestamps
    end
    add_index :shipment_locations, %i[shipment_id recorded_at]
  end
end
