class Admin::NasController < Admin::BaseController
  before_action :current_tenant
  before_action :set_site
  before_action :set_nas, only: %i[show edit update destroy]

  # GET /admin/nas or /admin/nas.json
  def index
    @nas = @site.nas
    @nas = case_insensitive_match(@nas, [ :nasname, :shortname, :type, :ports, :community, :description ])
  end

  # GET /admin/nas/1 or /admin/nas/1.json
  def show
  end

  # GET /admin/nas/new
  def new
    @nas = @site.nas.build
  end

  # GET /admin/nas/1/edit
  def edit
  end

  # POST /admin/nas or /admin/nas.json
  def create
    @nas = @site.nas.build(nas_params)
    respond_to do |format|
      if @nas.save
        format.html { redirect_to admin_tenant_site_nas_path(@tenant, @site, @nas), notice: "Nas was successfully created." }
        format.json { render :show, status: :created, location: admin_tenant_site_nas_path(@tenant, @site, @nas) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @nas.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/nas/1 or /admin/nas/1.json
  def update
    respond_to do |format|
      if @nas.update(nas_params)
        format.html { redirect_to admin_tenant_site_nas_path(@tenant, @site, @nas), notice: "Nas was successfully updated." }
        format.json { render :show, status: :ok, location: admin_tenant_site_nas_path(@tenant, @site, @nas) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @nas.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/nas/1 or /admin/nas/1.json
  def destroy
    @nas.destroy!
    respond_to do |format|
      format.html { redirect_to admin_tenant_site_nas_index_path(@tenant, @site), status: :see_other, notice: "Nas was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

    def set_site
      @site = @tenant.sites.find(params[:site_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_nas
      @nas = @site.nas.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def nas_params
      params.require(:nas).permit(:nasname, :shortname, :type, :ports, :secret, :server, :community, :description)
    end
end
