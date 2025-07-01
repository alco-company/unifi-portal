class PnumberController < ApplicationController
  def check_pnr
    @pnr = params[:pnr]
    if @pnr.blank?
      flash[:error] = "PNR cannot be blank."
      head :bad_request
    else
      # Here you would typically check the PNR against a database or an external service.
      # For demonstration, we will just simulate a successful check.
      render json: { exists: true }
    end
  end

  def check_phone
    @phone = params[:phone]
    if @phone.blank?
      head :bad_request
    else
      # Here you would typically check the phone number against a database or an external service.
      # For demonstration, we will just simulate a successful check.
      client = Client.find_by(phone: @phone)
      if client.nil?
        render json: { exists: false } and return
      end
      # If the client exists, we assume the phone number is valid.
      render json: { exists: true }
    end
  end
end
