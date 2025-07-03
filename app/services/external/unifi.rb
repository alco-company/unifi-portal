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

    # {
    #   "action": "AUTHORIZE_GUEST_ACCESS",
    #   "revokedAuthorization": {
    #     "authorizedAt": "2019-08-24T14:15:22Z",
    #     "authorizationMethod": "VOUCHER",
    #     "expiresAt": "2019-08-24T14:15:22Z",
    #     "dataUsageLimitMBytes": 1024,
    #     "rxRateLimitKbps": 1000,
    #     "txRateLimitKbps": 1000,
    #     "usage": {}
    #   },
    #   "grantedAuthorization": {
    #     "authorizedAt": "2019-08-24T14:15:22Z",
    #     "authorizationMethod": "VOUCHER",
    #     "expiresAt": "2019-08-24T14:15:22Z",
    #     "dataUsageLimitMBytes": 1024,
    #     "rxRateLimitKbps": 1000,
    #     "txRateLimitKbps": 1000,
    #     "usage": {}
    #   }
    # }
    def self.authorize_guest(url:, site_id:, client_id:, api_key:, time:, guest_max:, guest_rx:, guest_tx:)
      post_url = "#{url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions"

      body = {
        action: "AUTHORIZE_GUEST_ACCESS",
        timeLimitMinutes: time,
        dataUsageLimitMBytes: guest_max,
        rxRateLimitKbps: guest_rx,
        txRateLimitKbps: guest_tx
      }

      headers = {
        "X-API-KEY" => api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
      post_json(post_url, body: body, headers: headers)
    rescue => e
      Rails.logger.error("ERROR: Failed to authorize guest access: #{e.message}")
      { error: e.message }
    end

    # {
    #   "action": "UNAUTHORIZE_GUEST_ACCESS",
    #   "revokedAuthorization": {
    #   "authorizedAt": "2019-08-24T14:15:22Z",
    #   "authorizationMethod": "VOUCHER",
    #   "expiresAt": "2019-08-24T14:15:22Z",
    #   "dataUsageLimitMBytes": 1024,
    #   "rxRateLimitKbps": 1000,
    #   "txRateLimitKbps": 1000,
    #   "usage": {}
    #   }
    #   }
    def self.unauthorize_guest(url:, site_id:, client_id:, api_key:)
      post_url = "#{url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions"

      body = {
        action: "UNAUTHORIZE_GUEST_ACCESS"
      }

      headers = {
        "X-API-KEY" => api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }

      post_json(post_url, body: body, headers: headers)
    rescue => e
      Rails.logger.error("ERROR: Failed to unauthorize guest access: #{e.message}")
      { error: e.message }
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
