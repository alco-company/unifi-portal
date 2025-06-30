class Admin::SitesController < ApplicationController
  before_action :set_tenant
  before_action :set_site, only: %i[show edit update destroy]

  # GET /sites or /sites.json
  def index
    @sites = @tenant.sites
  end

  # GET /sites/1 or /sites/1.json
  def show
  end

  # GET /sites/new
  def new
    @site = @tenant.sites.new
  end

  # GET /sites/1/edit
  def edit
  end

  # POST /sites or /sites.json
  def create
    @site = @tenant.sites.new(site_params)
    if @site.save
      redirect_to admin_tenant_sites_path(@tenant), notice: "Site created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /sites/1 or /sites/1.json
  def update
    respond_to do |format|
      if @site.update(site_params)
        format.html { redirect_to admin_tenant_sites_path(@tenant), notice: "Site was successfully updated." }
        format.json { render :show, status: :ok, location: @site }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: admin_tenant_site_path(@tenant,@site).errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1 or /sites/1.json
  def destroy
    if @site.present?
      @site.destroy!

      respond_to do |format|
        format.html { redirect_to admin_tenant_sites_path(@tenant), status: :see_other, notice: "Site was successfully destroyed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_tenant_sites_path(@tenant), status: :see_other, alert: "Site not found." }
        format.json { render json: { error: "Site not found." }, status: :not_found }
      end
    end
  end

  private

    def set_tenant
      @tenant = Tenant.find(params[:tenant_id])
    end
    
    def set_site
      @site = @tenant.sites.find(params[:id]) rescue nil
    end
    # Only allow a list of trusted parameters through.
    def site_params
      params.expect(site: [ :tenant_id, :name, :url, :ssid, :api_key, :controller_url, :guest_max, :guest_rx, :guest_tx, :active ])
    end
end
