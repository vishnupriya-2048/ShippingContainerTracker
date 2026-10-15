class Shipment < ApplicationRecord
  enum :current_status, {
    prepared: "prepared",
    picked_up: "picked_up",
    in_transit: "in_transit",
    out_for_delivery: "out_for_delivery",
    delivered: "delivered",
    exception: "exception"
  }, default: :prepared

  has_many :locations, -> { chronological }, class_name: "ShipmentLocation", dependent: :destroy
  has_many :status_histories, -> { chronological }, class_name: "ShipmentStatusHistory", dependent: :destroy

  # Newest location per shipment. Written as a single-row-per-shipment subquery so
  # `Shipment.includes(:latest_location)` loads every latest point in one query
  # instead of one per shipment (or every point of every shipment).
  has_one :latest_location,
          -> { where(id: ShipmentLocation.select("DISTINCT ON (shipment_id) id").order(:shipment_id, recorded_at: :desc)) },
          class_name: "ShipmentLocation", inverse_of: :shipment

  validates :shipment_identifier, presence: true, uniqueness: true
  validates :source_address, :destination_address, presence: true
  validates :weight, :height, presence: true, numericality: true
  validates :source_latitude, :destination_latitude,
            presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :source_longitude, :destination_longitude,
            presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
end
