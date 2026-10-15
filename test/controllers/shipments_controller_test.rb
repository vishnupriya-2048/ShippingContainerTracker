require "test_helper"

class ShipmentsControllerTest < ActionDispatch::IntegrationTest
  def create_shipment(overrides = {})
    Shipment.create!({
      shipment_identifier: "MAEU-1001",
      weight: 500.0,
      height: 120.0,
      source_address: "Peenya Industrial Area, Bangalore, Karnataka, India",
      destination_address: "Guindy, Chennai, Tamil Nadu, India",
      source_latitude: 13.0285,
      source_longitude: 77.5197,
      destination_latitude: 13.0067,
      destination_longitude: 80.2206
    }.merge(overrides))
  end

  def shipment_params(overrides = {})
    {
      shipment_identifier: "HLCU-2002",
      weight: 250.0,
      height: 90.0,
      source_address: "Whitefield, Bangalore, Karnataka, India",
      destination_address: "T Nagar, Chennai, Tamil Nadu, India",
      source_latitude: 12.9698,
      source_longitude: 77.7500,
      destination_latitude: 13.0418,
      destination_longitude: 80.2341
    }.merge(overrides)
  end

  test "routes are RESTful for shipments" do
    assert_routing({ method: "get", path: "/shipments" }, { controller: "shipments", action: "index" })
    assert_routing({ method: "post", path: "/shipments" }, { controller: "shipments", action: "create" })
    assert_routing({ method: "get", path: "/shipments/new" }, { controller: "shipments", action: "new" })
    assert_routing({ method: "get", path: "/shipments/1/edit" }, { controller: "shipments", action: "edit", id: "1" })
    assert_routing({ method: "get", path: "/shipments/1" }, { controller: "shipments", action: "show", id: "1" })
    assert_routing({ method: "patch", path: "/shipments/1" }, { controller: "shipments", action: "update", id: "1" })
    assert_routing({ method: "delete", path: "/shipments/1" }, { controller: "shipments", action: "destroy", id: "1" })
  end

  test "index lists shipments" do
    create_shipment
    get shipments_url
    assert_response :success
    assert_includes response.body, "MAEU-1001"
  end

  test "show displays the shipment" do
    shipment = create_shipment
    get shipment_url(shipment)
    assert_response :success
    assert_includes response.body, "MAEU-1001"
    assert_includes response.body, "Guindy, Chennai"
  end

  test "new renders the form" do
    get new_shipment_url
    assert_response :success
    assert_select "form"
  end

  test "create persists a shipment and redirects to it" do
    assert_difference("Shipment.count", 1) do
      post shipments_url, params: { shipment: shipment_params }
    end
    shipment = Shipment.find_by!(shipment_identifier: "HLCU-2002")
    assert_redirected_to shipment_url(shipment)
    assert_equal "prepared", shipment.current_status
  end

  test "create with invalid data re-renders the form and saves nothing" do
    assert_no_difference("Shipment.count") do
      post shipments_url, params: { shipment: shipment_params(shipment_identifier: "") }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders the form" do
    get edit_shipment_url(create_shipment)
    assert_response :success
    assert_select "form"
  end

  test "update changes the shipment and redirects to it" do
    shipment = create_shipment
    patch shipment_url(shipment), params: { shipment: { weight: 999.0, current_status: "in_transit" } }
    assert_redirected_to shipment_url(shipment)
    shipment.reload
    assert_equal 999.0, shipment.weight
    assert_equal "in_transit", shipment.current_status
  end

  test "update with invalid data re-renders the form and does not change the record" do
    shipment = create_shipment
    patch shipment_url(shipment), params: { shipment: { source_latitude: 123 } }
    assert_response :unprocessable_entity
    assert_in_delta 13.0285, shipment.reload.source_latitude
  end

  test "destroy deletes the shipment and redirects to the index" do
    shipment = create_shipment
    assert_difference("Shipment.count", -1) do
      delete shipment_url(shipment)
    end
    assert_redirected_to shipments_url
  end

  test "root serves the dashboard" do
    assert_recognizes({ controller: "shipments", action: "index" }, "/")
  end

  test "dashboard embeds one map marker per shipment, at its latest location" do
    shipment = create_shipment
    shipment.locations.create!(latitude: 13.0, longitude: 77.0, recorded_at: 2.hours.ago)
    shipment.locations.create!(latitude: 13.5, longitude: 78.5, recorded_at: 1.hour.ago)
    create_shipment(shipment_identifier: "NO-LOCATION")

    get root_url
    assert_response :success

    markers = JSON.parse(css_select("[data-controller=map]").first["data-map-markers-value"])
    assert_equal 1, markers.size
    assert_equal "MAEU-1001", markers.first["identifier"]
    assert_in_delta 13.5, markers.first["lat"]
    assert_select "[data-map-target=row]", 2
    assert_includes response.body, "No location reported yet"
  end

  test "dashboard loads latest locations without N+1 queries" do
    3.times do |i|
      shipment = create_shipment(shipment_identifier: "SHIP-#{i}")
      3.times { |n| shipment.locations.create!(latitude: 13.0 + n, longitude: 77.0, recorded_at: n.hours.ago) }
    end

    queries = []
    counter = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("shipment_locations") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get root_url }

    assert_equal 1, queries.size
  end

  test "show passes the trail to the map controller as data values" do
    shipment = create_shipment
    shipment.locations.create!(latitude: 13.1, longitude: 77.6, recorded_at: 2.hours.ago)
    shipment.locations.create!(latitude: 13.2, longitude: 78.0, recorded_at: 1.hour.ago, address: "Hosur Road")

    get shipment_url(shipment)

    map = css_select("[data-controller=trail]").first
    path = JSON.parse(map["data-trail-path-value"])
    assert_equal [ [ 13.1, 77.6 ], [ 13.2, 78.0 ] ], path.map { |p| [ p["lat"], p["lng"] ] }
    current = JSON.parse(map["data-trail-current-value"])
    assert_equal [ 13.2, "Hosur Road" ], [ current["lat"], current["address"] ]
    assert_in_delta 13.0285, JSON.parse(map["data-trail-source-value"])["lat"]
    assert_in_delta 80.2206, JSON.parse(map["data-trail-destination-value"])["lng"]
  end

  test "show works for a shipment with no locations" do
    get shipment_url(create_shipment)
    assert_response :success
    assert_equal({}, JSON.parse(css_select("[data-controller=trail]").first["data-trail-current-value"]))
    assert_includes response.body, "No location reported yet"
  end

  test "show flags a delivered shipment as arrived for the map" do
    shipment = create_shipment(current_status: "delivered")
    get shipment_url(shipment)
    assert_equal "true", css_select("[data-controller=trail]").first["data-trail-arrived-value"]

    get shipment_url(create_shipment(shipment_identifier: "EN-ROUTE"))
    assert_equal "false", css_select("[data-controller=trail]").first["data-trail-arrived-value"]
  end

  test "show lists status history and location trail rows with map data" do
    shipment = create_shipment
    shipment.locations.create!(latitude: 13.1, longitude: 77.6, recorded_at: 2.hours.ago, speed: 42.5)
    shipment.locations.create!(latitude: 13.2, longitude: 78.0, recorded_at: 1.hour.ago)
    history = shipment.status_histories.create!(status: "picked_up", latitude: 13.1, longitude: 77.6,
                                                address: "Hosur Road", notes: "Left depot", changed_at: 2.hours.ago)

    get shipment_url(shipment)

    statuses = JSON.parse(css_select("[data-controller=trail]").first["data-trail-statuses-value"])
    assert_equal [ history.id, "Picked up" ], [ statuses.first["id"], statuses.first["status"] ]
    assert_select "[data-tabs-target=panel]", 1
    assert_select "[data-action='trail#focusStatus']", 1
    assert_includes response.body, "Left depot"
  end
end
