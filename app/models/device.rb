class Device < ApplicationRecord
  belongs_to :client
  belongs_to :site, optional: true

  def unauthorize
    if site.nil?
      return false
    end
    load_client_info
    result = External::Unifi.unauthorize_guest(
      url: site.controller_url,
      site_id: site.unifi_id,
      client_id: unifi_id,
      api_key: site.api_key
    )
    !result.nil? && result.dig("action").present? && result["action"] == "UNAUTHORIZE_GUEST_ACCESS" ?
      { success: true } :
      { success: false, error: result["error"] || "Failed to unauthorize guest access" }
  end

  def authorize
    if site.nil? || !client.active?
      return false
    end
    eu = External::Unifi::Base.new(site: site)
    if eu
      load_client_info(eu)
      result = eu.authorize_guest_access(
        mac_address: mac_address,
        minutes: time_limit,
        up: client.guest_tx,
        down: client.guest_rx,
        megabytes: client.guest_max
      )
      # result = eu.authorize_guest(
      #   url: site.controller_url,
      #   site_id: site.unifi_id,
      #   client_id: unifi_id,
      #   api_key: site.api_key,
      #   time: time_limit,
      #   guest_max: client.guest_max,
      #   guest_rx: client.guest_rx,
      #   guest_tx: client.guest_tx
      # )
      result ?
        { success: true } :
        { success: false, error: "Failed to authorize guest access" }
    end
  end

  def time_limit
    authentication_expire_at > 24.hours.from_now ? 1000000 : 1440
  end

  def load_client_info(eu)
    site_info = eu.site_info
    site.update(unifi_id: eu.get_id) if site_info
    unifi_client_id = eu.get_client_id(mac_address)
    unless unifi_client_id.nil?
      update unifi_id: unifi_client_id
    else
      Rails.logger.error("ERROR: Unifi client info not found for MAC address: #{mac_address}")
      nil
    end
  end
end
