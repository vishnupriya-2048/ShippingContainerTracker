class ShipmentsController < ApplicationController
  before_action :set_shipment, only: %i[show edit update destroy]

  def index
    @shipments = Shipment.includes(:latest_location).order(:shipment_identifier)
  end

  def show
    @locations = @shipment.locations.to_a
    @status_histories = @shipment.status_histories.to_a
    @status_histories = @shipment.status_histories.to_a
  end

  def new
    @shipment = Shipment.new
  end

  def edit
  end

  def create
    @shipment = Shipment.new(shipment_params)
    if @shipment.save
      redirect_to @shipment, notice: "Shipment was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @shipment.update(shipment_params)
      redirect_to @shipment, notice: "Shipment was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shipment.destroy!
    redirect_to shipments_path, notice: "Shipment was deleted.", status: :see_other
  end

  private

  def set_shipment
    @shipment = Shipment.find(params[:id])
  end

  def shipment_params
    params.expect(shipment: %i[
      shipment_identifier weight height current_status
      source_address destination_address
      source_latitude source_longitude destination_latitude destination_longitude
    ])
  end
end
