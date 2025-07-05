class Admin::SitesController < Admin::BaseController
  before_action :current_tenant
  before_action :set_site, only: %i[show edit update destroy]

  # GET /sites or /sites.json
  def index
    @sites = @tenant.sites
    @sites = case_insensitive_match(@sites, [ :name, :url, :ssid, :controller_url ])
  end

  # GET /sites/1 or /sites/1.json
  def show
  end

  # GET /sites/new
  def new
    @site = @tenant.sites.new(controller_type: "login")
  end

  # GET /sites/1/edit
  def edit
  end

  # POST /sites or /sites.json
  def create
    @site = @tenant.sites.new(site_params)
    if @site.save
      redirect_to admin_tenant_sites_path(@tenant), notice: "Site was successfully created."
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
        format.json { render json: admin_tenant_site_path(@tenant, @site).errors, status: :unprocessable_entity }
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

  def delete_all
    @sites = current_user.superuser? ? Site.all : Site.where(tenant_id: current_user.tenant_id)
    case_insensitive_match(@sites, [ :name, :url, :ssid, :controller_url ]).destroy_all

    respond_to do |format|
      format.html { redirect_to admin_tenant_sites_path(@tenant), status: :see_other, notice: "All sites were successfully deleted." }
      format.json { head :no_content }
    end
  end


  private

    def set_tenant
      @tenant = Tenant.find(params[:tenant_id]) || current_user.tenant
    end

    def set_site
      @site = @tenant.sites.find(params[:id]) rescue nil
    end
    # Only allow a list of trusted parameters through.
    def site_params
      params.expect(site: [ :tenant_id, :name, :url, :ssid, :username, :password, :unifi_id, :controller_type, :api_key, :controller_url, :guest_max, :guest_rx, :guest_tx, :active ])
    end
end
