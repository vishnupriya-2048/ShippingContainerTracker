class CreateShipmentStatusHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_status_histories do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :status, null: false
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.string :address
      t.text :notes
      t.datetime :changed_at, null: false

      t.timestamps
    end
  end
end
