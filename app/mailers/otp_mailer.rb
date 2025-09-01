class OtpMailer < ApplicationMailer
  def send_otp(user_email, otp_code)
    @otp_code = otp_code
    mail(
      to: user_email,
      subject: "Din OTP-kode til adgang til netværket",
      delivery_method: :mailersend,
      delivery_method_options: {
        api_key: ENV["MAILERSEND_API_TOKEN"]
      }
    )
  end
  
  def send_radius_otp(user_email, otp_code, device)
    @otp_code = otp_code
    @device = device
    @client = device.client
    @site = device.site
    @username = device.radius_username
    @expires_at = device.otp_expires_at
    
    mail(
      to: user_email,
      subject: "WiFi Login Credentials for #{@site&.name || 'Network'}",
      delivery_method: :mailersend,
      delivery_method_options: {
        api_key: ENV["MAILERSEND_API_TOKEN"]
      }
    )
  end
end
