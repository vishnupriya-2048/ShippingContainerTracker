class ShipmentStatusHistory < ApplicationRecord
  belongs_to :shipment

  enum :status, Shipment.current_statuses

  validates :status, :changed_at, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :chronological, -> { order(:changed_at) }
end
