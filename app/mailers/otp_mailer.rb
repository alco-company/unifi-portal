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
end
