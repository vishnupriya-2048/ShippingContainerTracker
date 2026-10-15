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
  validates :weight, :height, presence: true, numericality: { greater_than: 0 }
  validates :source_latitude, :destination_latitude, presence: true, numericality: { in: -90..90 }
  validates :source_longitude, :destination_longitude, presence: true, numericality: { in: -180..180 }

  def can_mark_exception?
    !(delivered? || exception?)
  end

  # Manual override (README `exception` status). Records the change in the status
  # history at the latest known position (the source if nothing was reported yet).
  # Returns false when the shipment is already delivered or in exception.
  def mark_exception
    with_lock do
      next false unless can_mark_exception?

      point = locations.last
      latitude, longitude, address =
        point ? [ point.latitude, point.longitude, point.address ] : [ source_latitude, source_longitude, source_address ]
      status_histories.create!(
        status: "exception", changed_at: Time.current, notes: "Marked as exception manually",
        latitude: latitude, longitude: longitude, address: address
      )
      update!(current_status: "exception")
      true
    end
  end
end
