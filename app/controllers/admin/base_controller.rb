class Admin::BaseController < ApplicationController
  # layout "admin/application"

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
end
