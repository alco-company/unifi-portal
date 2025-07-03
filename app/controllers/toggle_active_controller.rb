class ToggleActiveController < ApplicationController
  def update
    resource = params[:resource].constantize.find(params[:id])
    unless resource.nil?
      resource.update(active: params[:active])
      render json: { success: true }
    else
      render json: { success: false, error: "Resource not found" }, status: :not_found
    end
    if resource.is_a?(Client) and !resource.active?
      resource.devices.each do |device|
        result = device.unauthorize
        if result[:success]
          device.update!(
            last_authenticated_at: nil,
            authentication_expire_at: nil,
            active: false
          )
        end
      end
    end
  end
end
