class ShipmentStatusHistory < ApplicationRecord
  belongs_to :shipment

  enum :status, Shipment.current_statuses

  validates :status, :changed_at, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }

  scope :chronological, -> { order(:changed_at) }
end
