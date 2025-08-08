# app/services/sms_sender.rb
require "httparty"
require "uri"

class SmsSender
  API_URL = "https://api.smsapi.com/sms.do"
  API_TOKEN = ENV["SMSAPI_API_TOKEN"]

  def self.send_code(phone, code)
    raise ArgumentError, "Missing phone number" if phone.blank?

    normalized_phone = normalize_phone(phone)
    raise "SMS sending failed: bad phone number" if normalized_phone.nil?

    url = URI(API_URL)
    params = {
      to: normalized_phone,
      message: "Din engangskode er: #{code}",
      from: "unifiportal",
      format: "json"
    }

    headers = {
      "Authorization" => "Bearer #{API_TOKEN}"
    }

    response = HTTParty.post(url, body: params, headers: headers)
    unless response.success?
      raise "SMS sending failed: #{response.code} #{response.body}"
    end
    true
  end

  def self.normalize_phone(phone)
    phone = phone.strip
    # phone = phone.gsub(/\D/, "") # fjerner alt andet end cifre

    # Hvis det starter med 0 og derefter er 8 cifre → dansk mobil
    if phone.match?(/^0\d{8}$/)
      phone.sub(/^0/, "+45")
    elsif phone.match?(/^\d{8}$/)
      "+45#{phone}"
    elsif phone.start_with?("+45") and phone.length == 11
      phone
    else
      nil # "+#{phone}" # fallback, men pas på
    end
  end
end
