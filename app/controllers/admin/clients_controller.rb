require "csv"

class Admin::ClientsController < ApplicationController
  before_action :set_tenant
  before_action :set_site, only: %i[show edit update destroy]
  before_action :set_client, only: %i[ show edit update destroy ]

  # GET /clients or /clients.json
  def index
    @clients = @tenant.clients.all
  end

  # GET /clients/1 or /clients/1.json
  def show
  end

  # GET /clients/new
  def new
    @client = @tenant.clients.new
  end

  # GET /clients/1/edit
  def edit
  end

  def import
    if params[:file].present?
      @records = CSV.parse(File.read(params[:file].path), headers: true, col_sep: ";", encoding: "UTF-8")
      if @records and !@records.empty?
        @records.each do |row|
          next if row["email"].blank? && row["phone"].blank? # row["name"].blank? || 
          #   redirect_to admin_tenant_clients_path(@tenant), alert: "CSV file is missing required fields (name, email, phone) - no clients imported!"
          #   return
          # end
          Client.create!(
            tenant: @tenant,
            name:  row["name"]&.strip&.downcase&.titleize,
            email: row["email"]&.strip&.downcase,
            phone: row["phone"]&.squish,
            note:  row["note"],
            guest_max: row["guest_max"].to_i,
            guest_rx: row["guest_rx"].to_i,
            guest_tx: row["guest_tx"].to_i,
            active: row["active"].present? ? ActiveModel::Type::Boolean.new.cast(row["active"]) : true
          )
        end
        redirect_to admin_tenant_clients_path(@tenant), notice: "Clients imported successfully"
      else
        redirect_to admin_tenant_clients_path(@tenant), alert: "CSV file is empty - no clients imported!"
        return
      end
    else
      redirect_to admin_tenant_clients_path(@tenant), alert: "Please select a CSV file - no clients imported!"
    end
  end

  # POST /clients or /clients.json
  def create
    @client = Client.new(client_params)

    respond_to do |format|
      if @client.save
        format.html { redirect_to admin_tenant_clients_path(@client.tenant), notice: "Client was successfully created." }
        format.json { render :show, status: :created, location: admin_tenant_clients_path(@client.tenant) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /clients/1 or /clients/1.json
  def update
    respond_to do |format|
      if @client.update(client_params)
        format.html { redirect_to admin_tenant_clients_path(@client.tenant), notice: "Client was successfully updated." }
        format.json { render :show, status: :ok, location: admin_tenant_clients_path(@client.tenant) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /clients/1 or /clients/1.json
  def destroy
    if !@client.nil?
      @client.destroy!

      respond_to do |format|
        format.html { redirect_to admin_tenant_clients_path(@client.tenant), status: :see_other, notice: "Client was successfully destroyed." }
        format.json { head :no_content }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_client
      @client = @tenant.clients.find(params.expect(:id)) rescue nil
    end

    def set_tenant
      @tenant = Tenant.find(params[:tenant_id])
    end
    
    def set_site
      @site = @tenant.sites.find(params[:site_id]) rescue nil
    end

    # Only allow a list of trusted parameters through.
    def client_params
      params.expect(client: [ :tenant_id, :name, :email, :phone, :guest_max, :guest_rx, :guest_tx, :active, :note ])
    end
end
