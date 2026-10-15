class CreateShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipments do |t|
      t.string :shipment_identifier, null: false
      t.float :weight, null: false
      t.float :height, null: false
      t.string :source_address, null: false
      t.string :destination_address, null: false
      t.float :source_latitude, null: false
      t.float :source_longitude, null: false
      t.float :destination_latitude, null: false
      t.float :destination_longitude, null: false
      t.string :current_status, null: false, default: "prepared"

      t.timestamps
    end
    add_index :shipments, :shipment_identifier, unique: true
  end
end
