class ToggleActiveController < ApplicationController
  def update
    resource = params[:resource].constantize.find(params[:id])
    unless resource.nil?
      resource.update(active: params[:active])
      render json: { success: true }
    else
      render json: { success: false, error: "Resource not found" }, status: :not_found
    end
    if resource.is_a?(Client)
      resource.devices.each do |device|
        result = resource.active? ? device.authorize : device.unauthorize
        if result[:success] && resource.active?
          device.update(
            guest_max: @client.guest_max,
            guest_rx: @client.guest_rx,
            guest_tx: @client.guest_tx
          )
        else
          device.update(
            last_authenticated_at: nil,
            authentication_expire_at: nil,
            active: false
          )
        end
      end
    end
  end
end
