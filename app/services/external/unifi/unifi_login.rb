module External
  module Unifi
    class UnifiLogin
      include External::Unifi::Errors
      attr_accessor :base_url, :username, :password, :cookie, :site, :site_info
      def initialize(site: site, cookie: nil)
        @base_url = site.controller_url if site
        @username = site.username if site
        @password = site.password if site
        @cookie = cookie
        @site = site
        @site_info = nil
      end

      def login
        @cookie = Rails.env.test? ?
          "test_cookie" :
          External::Unifi::Calls.login_with_httparty(
            url: "#{base_url.chomp("/")}/api/login",
            username: username,
            password: password
          )
        return :logged_in unless @cookie.nil?
        :logged_out
      rescue StandardError => e
        raise "Error during Unifi login: #{e.message}"
      end

      def get_id
        @site_info["_id"]
      end

      def get_cookie_or_key
        @cookie || nil
      end


      # Fetches a list of sites from the Unifi API.
      # @param base_url [String] The base URL of the Unifi API.
      # @param key [String] The API key for authentication.
      # @return [Hash] A hash containing the list of sites and their details.
      # @example
      #   sites = UnifiLogin.list_sites("https://unifi.example.com", key: "your_api_key")
      #   {
      #     "meta": {
      #         "rc": "ok"
      #     },
      #     "data": [
      #         {
      #             "anonymous_id": "b77568ac-02ea-44ac-9939-a16619fd7d88",
      #             "name": "default",
      #             "external_id": "88f7af54-98f8-306a-a1c7-c9349722b1f6",
      #             "_id": "67f8dc74d97ad01d7c2fb5f4",
      #             "attr_no_delete": true,
      #             "attr_hidden_id": "default",
      #             "desc": "Default",
      #             "role": "admin",
      #             "device_count": 0
      #         },
      #         {
      #             "anonymous_id": "3ef9f818-4789-455b-a6dd-6a69bf5d4316",
      #             "name": "8xff0x6m",
      #             "external_id": "19d9aa6d-5b43-3ee7-ae18-d92d0f9360f3",
      #             "_id": "6803b1a107ae330ef4d6f5b8",
      #             "desc": "Thisted-Gymnasium_Linux",
      #             "role": "admin",
      #             "device_count": 68
      #         }
      #     ]
      # }
      #
      def list_sites(retry_number = 0)
        url = "#{base_url.chomp("/")}/api/self/sites"
        sites = External::Unifi::Calls.get_json(url, headers: headers)
        return [] if sites[:error].present?
        sites["data"] if sites["meta"]["rc"] == "ok"
      rescue LoginError => _e
        list_sites(retry_number + 1) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while listing sites: #{e.message}"
        []
      end

      def site_info(name: "default")
        sites = list_sites
        return nil if sites.empty?
        @site_info = sites.find { |site| site["name"] == name }
      end

      #   {
      #     "meta": {
      #         "rc": "ok"
      #     },
      #     "data": [
      #         {
      #             "site_id": "6803b1a107ae330ef4d6f5b8",
      #             "ap_mac": "ac:8b:a9:21:64:0d",
      #             "assoc_time": 1751760044,
      #             "latest_assoc_time": 1751760044,
      #             "oui": "Hui Zhou Gaoshengda Technology Co.,LTD",
      #             "user_id": "6821a79e0d906a5a0c7c2537",
      #             "last_ip": "10.20.2.103",
      #             "last_uplink_name": "57",
      #             "first_seen": 1747036062,
      #             "last_seen": 1752221165,
      #             "is_guest": false,
      #             "disconnect_timestamp": 1751760043,
      #             "last_radio": "na",
      #             "is_wired": false,
      #             "usergroup_id": "",
      #             "last_uplink_mac": "ac:8b:a9:21:64:0d",
      #             "last_connection_network_name": "Default",
      #             "mac": "4c:50:dd:da:e3:dd",
      #             "last_connection_network_id": "6803b1a107ae330ef4d71283",
      #             "hostname": "It",
      #             "_id": "6821a79e0d906a5a0c7c2537",
      #             "wlanconf_id": "6803b1a107ae330ef4d7127a",
      #             "_uptime_by_uap": 461121,
      #             "_last_seen_by_uap": 1752221165,
      #             "_is_guest_by_uap": false,
      #             "channel": 60,
      #             "channelWidth": 40,
      #             "radio": "na",
      #             "radio_name": "rai0",
      #             "essid": "ATV",
      #             "bssid": "ae:8b:a9:11:64:0f",
      #             "powersave_enabled": true,
      #             "is_11r": false,
      #             "user_group_id_computed": "6803b1a107ae330ef4d712b2",
      #             "anomalies": 0,
      #             "anon_client_id": "b4e9e72104e32e3d0a5f60e942faa6",
      #             "ccq": 0,
      #             "dhcpend_time": 185475794,
      #             "idletime": 3,
      #             "noise": -96,
      #             "nss": 2,
      #             "rx_rate": 6000,
      #             "rssi": 33,
      #             "satisfaction_now": 100,
      #             "satisfaction_real": 100,
      #             "satisfaction_reason": 0,
      #             "signal": -63,
      #             "tx_mcs": 7,
      #             "tx_power": 0,
      #             "tx_rate": 270000,
      #             "tx_retry_burst_count": 387,
      #             "satisfaction": 100,
      #             "hostname_source": "uap",
      #             "is_mlo": false,
      #             "radio_proto": "ac",
      #             "channel_width": 40,
      #             "satisfaction_avg": {
      #                 "total": 1848427,
      #                 "count": 18515
      #             },
      #             "uptime": 461121,
      #             "tx_bytes": 8823820,
      #             "rx_bytes": 21730459,
      #             "tx_packets": 54113,
      #             "rx_packets": 107079,
      #             "tx_retries": 952,
      #             "wifi_tx_attempts": 48408,
      #             "wifi_tx_dropped": 0,
      #             "wifi_tx_retries_percentage": 0.0,
      #             "qos_policy_applied": true,
      #             "_uptime_by_ugw": 3135689,
      #             "_last_seen_by_ugw": 1752221162,
      #             "_is_guest_by_ugw": false,
      #             "ip": "10.20.2.103",
      #             "gw_mac": "e4:38:83:62:74:f0",
      #             "gw_vlan": 1,
      #             "network": "Default",
      #             "network_id": "6803b1a107ae330ef4d71283",
      #             "_last_reachable_by_gw": 1752221155,
      #             "bytes-r": 27.41648461349267,
      #             "tx_bytes-r": 2.879092579464402,
      #             "rx_bytes-r": 24.53739203402827,
      #             "_uptime_by_usw": 3135689,
      #             "_last_seen_by_usw": 1752221162,
      #             "_is_guest_by_usw": false
      #         }
      #     ]
      # }
      def get_client_id(mac_address, retry_number = 0)
        url = "#{base_url.chomp("/")}/api/s/#{site.name}/stat/sta/#{CGI.escape(mac_address)}"
        client = External::Unifi::Calls.get_json(url, headers: headers)
        return nil if client[:error].present?
        return client["data"].first["_id"] if client["meta"]["rc"] == "ok"
        nil
      rescue LoginError => _e
        get_client(mac_address, retry_number + 1) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while getting client info: #{e.message}"
        nil
      end

      def get_client_info(mac_address, retry_number = 0)
        url = "#{base_url.chomp("/")}/api/s/#{site.name}/stat/sta/#{CGI.escape(mac_address)}"
        External::Unifi::Calls.get_json(url, headers: headers)
      end

      # {
      #   "meta": {
      #       "rc": "ok"
      #   },
      #   "data": [
      #       {
      #           "authorized_by": "voucher",
      #           "ap_mac": "60:22:32:a1:95:71",
      #           "is_returning": false,
      #           "roam_count": 5,
      #           "ip": "10.20.1.65",
      #           "start": 1751128225,
      #           "channel": 1,
      #           "voucher_code": "9617443618",
      #           "mac": "de:3b:b7:c5:74:bf",
      #           "radio": "ng",
      #           "duration": 3827,
      #           "hostname": "Muaz",
      #           "user_id": "686017c01f0dc649bd04df32",
      #           "bytes": 470715485,
      #           "site_id": "6803b1a107ae330ef4d6f5b8",
      #           "name": "TG-free",
      #           "voucher_id": "6803c92b07ae330ef4d72f88",
      #           "rx_bytes": 20162167,
      #           "end": 1782664225,
      #           "_id": "686018a11f0dc649bd04e063",
      #           "user_agent": "Mozilla/5.0 (Linux; Android 14; SM-A346B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/137.0.7151.115 Mobile Safari/537.36",
      #           "tx_bytes": 450553318,
      #           "expired": false
      #       },
      def list_guests(retry_number = 0, unauthorized: true)
        url = "#{base_url.chomp("/")}/api/s/#{site.name}/stat/guest"
        url = unauthorized ? "#{url}?filter=authorized.eq(false)" : url
        guests = External::Unifi::Calls.get_json(url, headers: headers)
        return [] if guests[:error].present?
        guests["data"] if guests["meta"]["rc"] == "ok"
      rescue LoginError => _e
        list_guests(retry_number + 1, unauthorized: unauthorized) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while listing guests: #{e.message}"
        []
      end

      def authorize_guest_access(retry_number = 0, mac_address:, minutes:, up:, down:, megabytes:)
        url = "#{base_url.chomp("/")}/api/s/#{site.name}/cmd/stamgr"
        body = {
          "cmd" => "authorize-guest",
          "mac" => mac_address,
          "minutes" => minutes,
          "up" => up,
          "down" => down,
          "bytes" => megabytes * 1024 * 1024 # Convert MB to bytes
        }
        response = External::Unifi::Calls.post_json(url, body: body, headers: headers)
        response["meta"]["rc"] == "ok"
      rescue LoginError => _e
        authorize_guest_access(retry_number + 1, mac_address: mac_address, minutes: minutes, up: up, down: down, megabytes: megabytes) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while authorizing guest access: #{e.message}"
        false
      end

      # && result.dig("action").present? && result["action"] == "UNAUTHORIZE_GUEST_ACCESS" ?
      def unauthorize_guest_access(mac_address, retry_number = 0)
        url = "#{base_url.chomp("/")}/api/s/#{site.name}/cmd/stamgr"
        body = {
          "cmd" => "unauthorize-guest",
          "mac" => mac_address
        }
        response = External::Unifi::Calls.post_json(url, body: body, headers: headers)
        response["meta"]["rc"] == "ok"
      rescue LoginError => _e
        unauthorize_guest_access(mac_address, retry_number + 1) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while unauthorizing guest access: #{e.message}"
        false
      end

      private

        def headers
          {
            "Accept" => "application/json",
            "Content-Type" => "application/json",
            "Cookie" => @cookie
          }
        end
    end
  end
end
