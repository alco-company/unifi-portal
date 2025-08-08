require "httparty"
# require "net/http"
# require "uri"
# require "json"

module External
  module Unifi
    class Calls
      include External::Unifi::Errors

      def self.login_with_curl(url: nil, username: nil, password: nil)
        # cookie_path = Rails.root.join("tmp", "cookie.txt")
        # cookie_path = "cookie.txt"
        cmd = <<~CURL
          curl --insecure --silent --location --request POST \
          --connect-timeout 1 --retry 1 --max-time 2 \
          --header 'Content-Type: application/json' \
          --cookie-jar cookie.txt \
          --data '{ "username": "#{username}", "password": "#{password}" }' \
          #{url}
        CURL

        response = JSON.parse `#{cmd}`
        if response && response["meta"]["rc"] == "ok"
          cookie = self.extract_unifi_cookie(cookie_path)
          File.delete(cookie_path) if File.exist?(cookie_path)
          cookie
        else
          nil
        end
      rescue StandardError => e
        Rails.logger.error("ERROR: Unifi::Calls - Failed to login with cURL: #{e.message}")
        nil
      end

      def self.login_with_httparty(url: nil, username: nil, password: nil)
        cookie_path = Rails.root.join("tmp", "cookie.txt")
        login_response = HTTParty.post(
          url,
          body: { username: username, password: password }.to_json,
          headers: { "Content-Type" => "application/json" },
          verify: false # skip SSL verification
        )
        if login_response.code == 200 && login_response["meta"]["rc"] == "ok"
          cookie = login_response.headers["set-cookie"]
          if cookie
            cookie = cookie.split(";").first # Get the first part of the cookie
            File.write(cookie_path, cookie) # Save to file
            cookie
          else
            nil
          end
        else
          Rails.logger.error("ERROR: Unifi::Calls - Failed to login with HTTParty: #{login_response.body}")
          nil
        end
      end

      def self.get_json(url, headers: {})
        # Ensure the URL is properly formatted
        url = url.chomp("/") if url.end_with?("/")

        # Make the GET request
        response = HTTParty.get(url, headers: headers, verify: false, follow_redirects: true)
        if response["meta"].present? && response["meta"]["msg"].present? && response["meta"]["msg"] == "api.err.LoginRequired"
          raise LoginError, "Unifi API login required"
        end
        response.parsed_response
      rescue LoginError => e
        raise LoginError, "Unifi API login required"
      rescue => e
        Rails.logger.error("ERROR: Unifi::Calls - Failed to GET #{url}: #{e.message}")
        return response.parsed_response if response && response.respond_to?(:parsed_response)
        { error: e.message }
      end

      def self.post_json(url, body: {}, headers: {})
        # Ensure the URL is properly formatted
        url = url.chomp("/") if url.end_with?("/")

        # Make the POST request
        response = HTTParty.post(url, body: body.to_json, headers: headers, verify: false, follow_redirects: true)
        if response["meta"].present? && response["meta"]["msg"].present? && response["meta"]["msg"] == "api.err.LoginRequired"
          raise LoginError, "Unifi API login required"
        end
        response.parsed_response
      rescue LoginError => e
        raise LoginError, "Unifi API login required"
      rescue => e
        Rails.logger.error("ERROR: Unifi::Calls - Failed to POST #{url}: #{e.message}")
        return response.parsed_response if response && response.respond_to?(:parsed_response)
        { error: e.message }
      end

      def self.extract_unifi_cookie(cookie_path)
        File.read(cookie_path).lines.filter { |l| l.include? "unifises" }[0].split("\t")[-2..].join("=")
      end
    end
  end
end
