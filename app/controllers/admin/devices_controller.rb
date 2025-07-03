class Admin::DevicesController < Admin::BaseController
  before_action :set_client
  before_action :current_tenant
  before_action :set_device, only: %i[ show edit update destroy ]

  # GET /devices or /devices.json
  def index
    @devices = @client.devices.all
  end

  # GET /devices/1 or /devices/1.json
  def show
  end

  # GET /devices/new
  def new
    @device = @client.devices.new
  end

  # GET /devices/1/edit
  def edit
  end

  # POST /devices or /devices.json
  def create
    @device = @client.devices.new(device_params)

    respond_to do |format|
      if @device.save
        format.html { redirect_to admin_client_devices_path(@client), notice: "Device was successfully created." }
        format.json { render :show, status: :created, location: admin_client_devices_path(@client) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /devices/1 or /devices/1.json
  def update
    respond_to do |format|
      if @device.update(device_params)
        format.html { redirect_to admin_client_devices_path(@client), notice: "Device was successfully updated." }
        format.json { render :show, status: :ok, location: admin_client_devices_path(@client) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /devices/1 or /devices/1.json
  def destroy
    if !@device.nil?
      @device.destroy!

      respond_to do |format|
        format.html { redirect_to admin_client_devices_path(@client), status: :see_other, notice: "Device was successfully destroyed." }
        format.json { head :no_content }
      end
    end
  end

  private

    def set_client
      @client = Client.find(params.expect(:client_id)) rescue nil
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_device
      @device = @client.devices.find(params.expect(:id)) rescue nil
    end

    # Only allow a list of trusted parameters through.
    def device_params
      params.expect(device: [ :client_id, :last_ap, :mac_address, :site_id, :last_authenticated_at, :last_otp, :authentication_expire_at ])
    end
end
