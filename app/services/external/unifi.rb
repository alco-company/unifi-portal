require "httparty"

module External
  class Unifi
    include HTTParty
    format :json

    # Only skip verification in development
    default_options.update(
      verify: !Rails.env.development?
    )
    def self.get_sites(base_url, key: nil)
      headers = {
        "X-API-KEY" => key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }

      url = "#{base_url.chomp("/")}/proxy/network/integration/v1"
      get_json("#{url}/sites", headers: headers)
    end

    def self.get_client(base_url, site_id, mac_address, key: nil)
      headers = {
        "X-API-KEY" => key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
      url = "#{base_url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients?filter=macAddress.eq('#{CGI.escape(mac_address)}')"
      get_json(url, headers: headers)
    end

    def self.authorize_guest(url:, site_id:, client_id:, api_key:)
      post_url = "#{url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions"

      body = {
        action: "AUTHORIZE_GUEST_ACCESS",
        timeLimitMinutes: 2000,
        dataUsageLimitMBytes: 10_000,
        rxRateLimitKbps: 20000,
        txRateLimitKbps: 20000
      }

      headers = {
        "X-API-KEY" => api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
      post_json(post_url, body: body, headers: headers)
    end

    def self.success_redirect(base_url, mac, token)
      "#{base_url}/guest/s/default?mac=#{mac}&token=#{token}"
    end

    def self.get_json(url, headers: {})

      # Ensure the URL is properly formatted
      url = url.chomp("/") if url.end_with?("/")

      # Make the GET request
      response = HTTParty.get(url, headers: headers, verify: false)
      raise "API error: #{response.code} #{response.body}" unless response.success?
      
      response.parsed_response
    end

    def self.post_json(url, body: {}, headers: {})
      # Ensure the URL is properly formatted
      url = url.chomp("/") if url.end_with?("/")

      # Make the POST request
      response = HTTParty.post(url, body: body.to_json, headers: headers, verify: false)
      raise "API error: #{response.code} #{response.body}" unless response.success?

      response.parsed_response
    end
  end
end