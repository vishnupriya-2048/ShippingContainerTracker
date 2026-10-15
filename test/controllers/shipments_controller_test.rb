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
end
