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
        cookie_path = "cookie.txt"
        cmd = <<~CURL
          curl --insecure --silent --location --request POST \
          --connect-timeout 1 --retry 1 --max-time 2 \
          --header 'Content-Type: application/json' \
          -c 'cookie.txt' \
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


# def login_with_net_http
#   # # Logic for logging in to the Unifi API
#   # headers = {
#   #   # "vary" => "origin,accept-encoding",
#   #   # "X-Frame-Options" => "DENY",
#   #   # "Content-Encoding" => "gzip",
#   #   # "Transfer-Encoding" => "chunked",
#   #   "Content-Type" => "application/json;charset=UTF-8"
#   #   # "Keep-Alive" => "timeout=30"
#   # }
#   # url = "#{@base_url.chomp("/")}/api/login"
#   # body = {
#   #   username: @username,
#   #   password: @password
#   # }
#   # response = External::Unifi::Calls.post_json(url, body: body, headers: headers)
#   # return false if response[:error]
#   # if response["meta"]["rc"] == "ok"
#   #   cookie = response.headers["set-cookie"]
#   #   :logged_in
#   # else
#   #   :logged_out
#   # end

#   # response = IO.popen([
#   #   "curl",
#   #   "--silent",
#   #   "--location",
#   #   "--request", "POST",
#   #   "--header", "Content-Type: application/json",
#   #   "-c", cookie_path,
#   #   "--data", body.to_json,
#   #   url
#   # ]) { |io| io.read }

#   # puts "cURL response: #{response}"

#   uri = URI.parse("#{url.chomp("/")}/api/login")
#   http = Net::HTTP.new(uri.host, uri.port)
#   http.use_ssl = true if uri.scheme == "https"

#   request = Net::HTTP::Post.new(uri.request_uri)
#   request["Content-Type"] = "application/json"
#   request.body = { username: username, password: password }.to_json

#   response = http.request(request)
#   return false unless response.is_a?(Net::HTTPSuccess)

#   # Return the cookie contents
#   if response["set-cookie"]
#     response["set-cookie"]
#   else
#     false
#   end
# end
