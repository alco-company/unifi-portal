module External
  module Unifi
    class UnifiLogin
      include External::Unifi::Errors
      attr_accessor :base_url, :username, :password, :cookie
      def initialize(site: site, cookie: nil)
        @base_url = site.controller_url if site
        @username = site.username if site
        @password = site.password if site
        @cookie = cookie
      end

      def login
        @cookie = External::Unifi::Calls.login_with_curl(
          url: "#{base_url.chomp("/")}/api/login",
          username: username,
          password: password
        )
        return :logged_in unless @cookie.nil?
        :logged_out
      rescue StandardError => e
        raise "Error during Unifi login: #{e.message}"
      end

      def get_cookie
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
        headers = {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "Cookie" => cookie
        }
        url = "#{base_url.chomp("/")}/api/self/sites"
        sites = External::Unifi::Calls.get_json(url, headers: headers)
        return [] if sites[:error].present?
        sites["data"] if sites["meta"]["rc"] == "ok"
      rescue LoginError => e
        puts "trying to login (#{retry_number + 1})"
        list_sites(retry_number + 1) if retry_number < 3 && login == :logged_in
      rescue StandardError => e
        Rails.logger.error "ERROR: Other error while listing sites: #{e.message}"
        []
      end

      def list_guests(try_number = 0)
        puts "trying to login #(#{try_number})"
        headers = {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "Cookie" => cookie
        }
        url = "#{base_url.chomp("/")}/api/s/default/stat/guest"
        response = External::Unifi::Calls.get_json(url, headers: headers)
        if response["meta"].present? && response["meta"]["rc"] == "ok"
          return response["data"]
        end
        if response["meta"].present? && response["meta"]["msg"].present? && response["meta"]["msg"] == "api.err.LoginRequired"
          return list_guests(try_number + 1) if login == :logged_in && try_number < 3
          return []
        end
        Rails.logger.error("ERROR: UnifiLogin - Failed to get client info: #{response['meta']['msg']}")
        []
      end
    end
  end
end
