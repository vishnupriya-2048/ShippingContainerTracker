ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # A valid shipment on the equator: source at 0°E, destination 1° east (~111 km).
    def build_shipment(**overrides)
      Shipment.new({
        shipment_identifier: "TEST-1", weight: 100.0, height: 50.0,
        source_address: "Source", destination_address: "Destination",
        source_latitude: 0, source_longitude: 0,
        destination_latitude: 0, destination_longitude: 1.0
      }.merge(overrides))
    end

    def create_shipment(**overrides)
      build_shipment(**overrides).tap(&:save!)
    end
  end
end
