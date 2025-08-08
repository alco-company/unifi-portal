
module External
  module Unifi
    # Unifi API client for interacting with Unifi Network Integration API.
    # This client provides methods to retrieve sites, clients, and manage guest access.
    # It uses HTTParty for making HTTP requests and handles JSON responses.
    #
    class Base
      attr_accessor :site, :state, :unifi, :site_info, :cookie_key

      def initialize(site: nil, cookie: nil)
        @site = site
        @cookie = cookie
        @state = cookie ? :logged_in : :logged_out
        @unifi = site.login? ?
          External::Unifi::UnifiLogin.new(site: site, cookie: cookie) :
          External::Unifi::UnifiApiKey.new(site: site)
        @site_info = nil
      end

      def get_id
        unifi_get_id
      end

      def site_info
        @site_info ||= unifi_get_site_info(name: site.name)
      end

      def get_cookie_or_key
        @cookie_key ||= unifi_get_cookie_or_key
      end

      def list_sites
        unifi_list_sites
      end

      def list_guests(unauthorized: true)
        unifi_list_guests(unauthorized: unauthorized)
      end

      def get_client_id(mac_address)
        unifi_get_client_id(mac_address)
      end

      def is_mac_authorized?(mac_address)
        unifi_is_mac_authorized?(mac_address)
      end
      #
      # Authorizes guest access for a given MAC address.
      # @param mac_address [String] The MAC address of the guest device.
      # @param minutes [Integer] The duration in minutes for which the guest access is valid - default is 1440 minutes (24 hours).
      # @param up [Integer] The upload speed limit in Kbps - default is 200.
      # @param down [Integer] The download speed limit in Kbps - default is 200.
      # @param megabytes [Integer] The data limit in MB - default is 0 (unlimited).
      def authorize_guest_access(mac_address:, minutes: 1440, up: 200, down: 200, megabytes: 0)
        unifi_authorize(mac_address, minutes: minutes, up: up, down: down, megabytes: megabytes)
      end

      def revoke_guest_access(mac_address)
        unifi_unauthorize(mac_address)
      end

      private

        # IMPLEMENTATION OF THE UNIFI API CLIENT METHODS
        # stubs - actual implementation is in the UnifiLogin or UnifiApiKey classes
        #

        # return true|false
        def logged_in?
          unifi_login if state == :logged_out
          state == :logged_in
        end

        # return true|false
        def unifi_login
          @state = unifi.login
          state == :logged_in
        end

        def unifi_get_id
          unifi.get_id if logged_in?
        end

        def unifi_get_cookie_or_key
          unifi.get_cookie_or_key if logged_in?
        end

        def unifi_list_sites
          unifi.list_sites if logged_in?
        end

        def unifi_get_site_info(name: nil)
          unifi.site_info(name: name) if logged_in?
        end

        def unifi_list_guests(unauthorized: true)
          unifi.list_guests(0, unauthorized: unauthorized) if logged_in?
        end

        # named values array or empty array
        def unifi_get_client_id(mac_address)
          unifi.get_client_id(mac_address) if logged_in?
        end

        def unifi_is_mac_authorized?(mac_address)
          unifi.is_mac_authorized?(mac_address) if logged_in?
        end

        # return true|false
        def unifi_authorize(mac_address, minutes:, up:, down:, megabytes:)
          unifi.authorize_guest_access(
            mac_address: mac_address,
            minutes: minutes,
            up: up,
            down: down,
            megabytes: megabytes) if logged_in?
        end

        # return true|false
        def unifi_unauthorize(mac_address)
          unifi.unauthorize_guest_access(mac_address) if logged_in?
        end
    end
  end
end
