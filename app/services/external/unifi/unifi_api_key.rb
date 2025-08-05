module External
  module Unifi
    # Unifi API Key service for managing API keys.
    # This service provides methods to retrieve and manage API keys for Unifi Network Integration.
    class UnifiApiKey
      attr_accessor :base_url, :api_key, :headers, :site, :site_info

      def initialize(site: nil)
        @base_url = "#{site&.controller_url&.chomp("/")}/proxy/network/integration/v1"
        @api_key = site&.api_key
        @site = site
        @site_info = nil
        @headers = {
          "X-API-KEY" => api_key,
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      end

      def login
        External::Unifi::Calls.get_json("#{base_url}/sites", headers: headers)
        :logged_in
      rescue StandardError => e
        Rails.logger.error("ERROR: UnifiApiKey - Failed to login: #{e.message}")
        :logged_out
      end

      def get_id
        @site_info["data"].first["id"]
      end

      # Retrieves the API key for the Unifi Network Integration.
      # @return [String] The API key.
      def get_cookie_or_key
        site.api_key
      end

      def list_sites
        External::Unifi::Calls.get_json("#{base_url}/sites", headers: headers)
      rescue StandardError => e
        Rails.logger.error("ERROR: UnifiApiKey - Failed to list sites: #{e.message}")
        { error: e.message }
      end

      def site_info(name:)
        @site_info = list_sites.find { |site| site["name"] == name }
      end

      def get_client_id(mac_address)
        url = "#{base_url}/sites/#{site.site_unifi_id}/clients?filter=macAddress.eq('#{CGI.escape(mac_address)}')"
        ci = External::Unifi::Calls.get_json(url, headers: headers)
        return ci["data"].first["id"] if ci && ci["data"].present? && ci["count"] == 1
        nil
      end

      # result.dig("action").present? && result["action"] == "AUTHORIZE_GUEST_ACCESS"
      def authorize_guest_access(retry_number = 0, mac_address:, minutes:, up:, down:, megabytes:)
        body = {
          action: "AUTHORIZE_GUEST_ACCESS",
          timeLimitMinutes: minutes,
          dataUsageLimitMBytes: megabytes,
          rxRateLimitKbps: down,
          txRateLimitKbps: up
        }
        post_url = "#{base_url}/sites/#{site.site_unifi_id}/clients/#{mac_address}/actions"
        response = External::Unifi::Calls.post_json(post_url, body: body, headers: headers)
        return false if response[:error].present?
        response["meta"]["rc"] == "ok"
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while authorizing guest access: #{e.message}"
        false
      end

      # && result.dig("action").present? && result["action"] == "UNAUTHORIZE_GUEST_ACCESS" ?
      def unauthorize_guest_access(mac_address, retry_number = 0)
        post_url = "#{base_url}/sites/#{site.site_unifi_id}/clients/#{mac_address}/actions"
        body = {
          action: "UNAUTHORIZE_GUEST_ACCESS"
        }
        response = External::Unifi::Calls.post_json(post_url, body: body, headers: headers)
        return false if response[:error].present?
        response["meta"]["rc"] == "ok"
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while unauthorizing guest access: #{e.message}"
        false
      end

      private

        def set_site_id
          site.site_unifi_id ||= site_info(site.name)["id"]
        end
    end
  end
end

# class Unifi
#   include HTTParty
#   format :json

#   # Only skip verification in development
#   default_options.update(
#     verify: !Rails.env.development?
#   )
#   def self.get_sites(base_url, key: nil)
#     headers = {
#       "X-API-KEY" => key,
#       "Accept" => "application/json",
#       "Content-Type" => "application/json"
#     }

#     url = "#{base_url.chomp("/")}/proxy/network/integration/v1"
#     get_json("#{url}/sites", headers: headers)
#   end


#   # {
#   #   "action": "AUTHORIZE_GUEST_ACCESS",
#   #   "revokedAuthorization": {
#   #     "authorizedAt": "2019-08-24T14:15:22Z",
#   #     "authorizationMethod": "VOUCHER",
#   #     "expiresAt": "2019-08-24T14:15:22Z",
#   #     "dataUsageLimitMBytes": 1024,
#   #     "rxRateLimitKbps": 1000,
#   #     "txRateLimitKbps": 1000,
#   #     "usage": {}
#   #   },
#   #   "grantedAuthorization": {
#   #     "authorizedAt": "2019-08-24T14:15:22Z",
#   #     "authorizationMethod": "VOUCHER",
#   #     "expiresAt": "2019-08-24T14:15:22Z",
#   #     "dataUsageLimitMBytes": 1024,
#   #     "rxRateLimitKbps": 1000,
#   #     "txRateLimitKbps": 1000,
#   #     "usage": {}
#   #   }
#   # }
#   def self.authorize_guest(url:, site_id:, client_id:, api_key:, time:, guest_max:, guest_rx:, guest_tx:)
#     post_url = "#{url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions"

#     body = {
#       action: "AUTHORIZE_GUEST_ACCESS",
#       timeLimitMinutes: time,
#       dataUsageLimitMBytes: guest_max,
#       rxRateLimitKbps: guest_rx,
#       txRateLimitKbps: guest_tx
#     }

#     headers = {
#       "X-API-KEY" => api_key,
#       "Accept" => "application/json",
#       "Content-Type" => "application/json"
#     }
#     post_json(post_url, body: body, headers: headers)
#   rescue => e
#     Rails.logger.error("ERROR: Failed to authorize guest access: #{e.message}")
#     { error: e.message }
#   end

#   # {
#   #   "action": "UNAUTHORIZE_GUEST_ACCESS",
#   #   "revokedAuthorization": {
#   #   "authorizedAt": "2019-08-24T14:15:22Z",
#   #   "authorizationMethod": "VOUCHER",
#   #   "expiresAt": "2019-08-24T14:15:22Z",
#   #   "dataUsageLimitMBytes": 1024,
#   #   "rxRateLimitKbps": 1000,
#   #   "txRateLimitKbps": 1000,
#   #   "usage": {}
#   #   }
#   #   }
#   def self.unauthorize_guest(url:, site_id:, client_id:, api_key:)
#     post_url = "#{url.chomp("/")}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions"

#     body = {
#       action: "UNAUTHORIZE_GUEST_ACCESS"
#     }

#     headers = {
#       "X-API-KEY" => api_key,
#       "Accept" => "application/json",
#       "Content-Type" => "application/json"
#     }

#     post_json(post_url, body: body, headers: headers)
#   rescue => e
#     Rails.logger.error("ERROR: Failed to unauthorize guest access: #{e.message}")
#     { error: e.message }
#   end

#   def self.success_redirect(base_url, mac, token)
#     "#{base_url}/guest/s/default?mac=#{mac}&token=#{token}"
#   end
# end
