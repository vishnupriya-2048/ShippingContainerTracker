# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_16_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "shipment_locations", force: :cascade do |t|
    t.bigint "shipment_id", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.datetime "recorded_at", null: false
    t.string "address"
    t.float "speed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipment_id", "recorded_at"], name: "index_shipment_locations_on_shipment_id_and_recorded_at", unique: true
    t.check_constraint "latitude >= '-90'::integer::double precision AND latitude <= 90::double precision AND longitude >= '-180'::integer::double precision AND longitude <= 180::double precision", name: "shipment_locations_coordinate_range"
  end

  create_table "shipment_status_histories", force: :cascade do |t|
    t.bigint "shipment_id", null: false
    t.string "status", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.string "address"
    t.text "notes"
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipment_id", "changed_at"], name: "index_shipment_status_histories_on_shipment_id_and_changed_at"
    t.check_constraint "latitude >= '-90'::integer::double precision AND latitude <= 90::double precision AND longitude >= '-180'::integer::double precision AND longitude <= 180::double precision", name: "shipment_status_histories_coordinate_range"
    t.check_constraint "status::text = ANY (ARRAY['prepared'::character varying, 'picked_up'::character varying, 'in_transit'::character varying, 'out_for_delivery'::character varying, 'delivered'::character varying, 'exception'::character varying]::text[])", name: "shipment_status_histories_known_status"
  end

  create_table "shipments", force: :cascade do |t|
    t.string "shipment_identifier", null: false
    t.float "weight", null: false
    t.float "height", null: false
    t.string "source_address", null: false
    t.string "destination_address", null: false
    t.float "source_latitude", null: false
    t.float "source_longitude", null: false
    t.float "destination_latitude", null: false
    t.float "destination_longitude", null: false
    t.string "current_status", default: "prepared", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipment_identifier"], name: "index_shipments_on_shipment_identifier", unique: true
    t.check_constraint "current_status::text = ANY (ARRAY['prepared'::character varying, 'picked_up'::character varying, 'in_transit'::character varying, 'out_for_delivery'::character varying, 'delivered'::character varying, 'exception'::character varying]::text[])", name: "shipments_known_status"
    t.check_constraint "source_latitude >= '-90'::integer::double precision AND source_latitude <= 90::double precision AND destination_latitude >= '-90'::integer::double precision AND destination_latitude <= 90::double precision", name: "shipments_latitude_range"
    t.check_constraint "source_longitude >= '-180'::integer::double precision AND source_longitude <= 180::double precision AND destination_longitude >= '-180'::integer::double precision AND destination_longitude <= 180::double precision", name: "shipments_longitude_range"
    t.check_constraint "weight > 0::double precision AND height > 0::double precision", name: "shipments_positive_size"
  end

  add_foreign_key "shipment_locations", "shipments"
  add_foreign_key "shipment_status_histories", "shipments"
end
