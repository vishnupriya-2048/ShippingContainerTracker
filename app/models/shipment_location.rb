class ShipmentLocation < ApplicationRecord
  belongs_to :shipment

  validates :recorded_at, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :speed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :chronological, -> { order(:recorded_at) }
end
