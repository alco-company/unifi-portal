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
      url = "#{base_url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients"
      filter = "macAddress.eq('#{mac_address}')"
      response = get_json("#{url}?filter=#{CGI.escape(filter)}", headers: headers)
      response.first # assuming only one match
    end

    def self.authorize_guest(site_id:, client_id:, api_key:)
      post_url = "/sites/#{site_id}/clients/#{client_id}/actions"

      body = {
        action: "AUTHORIZE_GUEST_ACCESS",
        timeLimitMinutes: 2,
        dataUsageLimitMBytes: 10_000,
        rxRateLimitKbps: 20,
        txRateLimitKbps: 20
      }

      headers = {
        "X-API-KEY" => api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }

      response = HTTParty.post(post_url, body: body.to_json, headers: headers)
      raise "Authorization failed: #{response.body}" unless response.success?

      response.parsed_response
    end

    def self.get_json(url, headers: {})

      # Ensure the URL is properly formatted
      url = url.chomp("/") if url.end_with?("/")

      # Make the GET request
      response = HTTParty.get(url, headers: headers, verify: false)
      raise "API error: #{response.code} #{response.body}" unless response.success?
      
      response.parsed_response
    end
  end
end