# app/services/sms_sender.rb
require "httparty"
require "uri"

class SmsSender
  API_URL = "https://api.smsapi.com/sms.do"
  API_TOKEN = ENV["SMSAPI_API_TOKEN"]

  def self.send_code(phone, code)
    raise ArgumentError, "Missing phone number" if phone.blank?

    url = URI(API_URL)
    params = {
      to: phone,
      message: "Din engangskode er: #{code}",
      from: "Mortimer",
      format: "json"
    }

    headers = {
      "Authorization" => "Bearer #{API_TOKEN}"
    }

    response = HTTParty.post(url, body: params, headers: headers)
    unless response.success?
      raise "SMS sending failed: #{response.code} #{response.body}"
    end
  end
end