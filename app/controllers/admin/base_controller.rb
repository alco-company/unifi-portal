class Admin::BaseController < ApplicationController
  # layout "admin/application"
  helper_method :current_tenant

  # Ensure the user is logged in as an admin
  before_action :require_user!

  # Ensure the user has admin privileges
  before_action :restrict_to_tenant!

  def require_user!
    redirect_to admin_login_path unless current_user
  end

  def restrict_to_tenant!
    unless current_user.superuser?
      @tenant = current_user.tenant
    end
  end

  def current_tenant
    case params[:controller]
    when "admin/tenants"; @tenant ||= Tenant.find(params[:id]) if params[:id].present?
    when "admin/devices"; @tenant ||= @client.tenant if @client.present?
    else @tenant ||= params[:tenant_id].present? ? Tenant.find(params[:tenant_id]) : nil
    end
    @tenant || current_user&.tenant
  end
end
