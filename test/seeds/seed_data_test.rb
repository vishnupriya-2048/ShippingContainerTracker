require "test_helper"

class SeedDataTest < ActiveSupport::TestCase
  class FakeProducer
    attr_reader :messages
    def initialize = @messages = []
    def produce_many_sync(batch) = @messages.concat(batch)
  end

  def load_seeds(producer = @producer)
    original = Karafka.method(:producer)
    Karafka.define_singleton_method(:producer) { producer }
    capture_io { load Rails.root.join("db/seeds.rb"), true }
  ensure
    Karafka.define_singleton_method(:producer, original)
  end

  def payloads = @producer.messages.map { |m| JSON.parse(m[:payload]) }

  setup do
    ShipmentLocation.delete_all
    ShipmentStatusHistory.delete_all
    Shipment.delete_all
    @producer = FakeProducer.new
  end

  test "seeds create only shipments, never locations or status history" do
    load_seeds

    assert_equal 5, Shipment.count
    assert_equal 0, ShipmentLocation.count
    assert_equal 0, ShipmentStatusHistory.count
    assert Shipment.all.all?(&:prepared?)
  end

  test "each shipment gets at least 50 chronological points published, keyed by identifier" do
    load_seeds

    by_shipment = @producer.messages.group_by { |m| m[:key] }
    assert_equal Shipment.pluck(:shipment_identifier).sort, by_shipment.keys.sort
    by_shipment.each do |identifier, messages|
      assert_operator messages.size, :>=, 50, "#{identifier} has #{messages.size} points"
      assert_equal [ ShipmentLocationsConsumer::TOPIC ], messages.map { |m| m[:topic] }.uniq
      times = messages.map { |m| JSON.parse(m[:payload])["recorded_at"] }
      assert_equal times.sort, times
      assert times.all?(Integer), "recorded_at must be epoch milliseconds"
    end
  end

  test "first and last published points match the shipment source and destination" do
    load_seeds

    Shipment.find_each do |s|
      points = payloads.select { |p| p["shipment_identifier"] == s.shipment_identifier }
      assert_equal [ s.source_latitude, s.source_longitude ], points.first.values_at("latitude", "longitude")
      assert_equal [ s.destination_latitude, s.destination_longitude ], points.last.values_at("latitude", "longitude")
    end
  end

  test "every published point passes the consumer's validation" do
    load_seeds

    @producer.messages.each { |m| assert LocationPayload.parse(m[:payload]) }
  end

  test "running seeds twice creates no duplicate shipments and republishes identical messages" do
    load_seeds
    first = @producer.messages.dup
    assert_equal 5, Shipment.count

    @producer = FakeProducer.new
    load_seeds

    assert_equal 5, Shipment.count
    assert_equal first, @producer.messages
  end

  test "shipments that already have locations are not republished" do
    load_seeds
    shipment = Shipment.find_by!(shipment_identifier: "SEED-0001")
    shipment.locations.create!(latitude: 0, longitude: 0, recorded_at: Time.current)

    @producer = FakeProducer.new
    load_seeds

    assert_not_includes @producer.messages.map { |m| m[:key] }, "SEED-0001"
  end
end
