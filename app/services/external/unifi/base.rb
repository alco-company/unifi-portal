
module External
  module Unifi
    # Unifi API client for interacting with Unifi Network Integration API.
    # This client provides methods to retrieve sites, clients, and manage guest access.
    # It uses HTTParty for making HTTP requests and handles JSON responses.
    #
    class Base
      attr_accessor :site, :state, :unifi, :cookie, :site_info

      def initialize(site: nil, cookie: nil)
        @site = site
        @cookie = cookie
        @state = cookie ? :logged_in : :logged_out
        @unifi = site.login? ?
          External::Unifi::UnifiLogin.new(site: site, cookie: cookie) :
          External::Unifi::UnifiApiKey.new(site: site)
        @site_info = nil
      end

      def get_site_info
        unifi_site_info if logged_in?
      end

      def get_cookie
        unifi_login unless logged_in?
        cookie
      end

      def get_client_info
        unifi_login unless logged_in?
      end

      def authorize_guest_access
      end

      def revoke_guest_access
      end

      private

        def logged_in?
          state == :logged_in || unifi_login
        end

        def unifi_login
          state = unifi.login
          cookie = unifi.get_cookie if state == :logged_in
          state == :logged_in
        end

        def unifi_site_info
          site_info ||= unifi.list_sites
        end

        def unifi_client_info(mac_address)
          unifi.get_client(mac_address)
        end
    end
  end
end
