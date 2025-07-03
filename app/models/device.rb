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
    load_client_info
    result = External::Unifi.authorize_guest(
      url: site.controller_url,
      site_id: site.unifi_id,
      client_id: unifi_id,
      api_key: site.api_key,
      guest_max: client.guest_max,
      guest_rx: client.guest_rx,
      guest_tx: client.guest_tx
    )
    !result.nil? && result.dig("action").present? && result["action"] == "AUTHORIZE_GUEST_ACCESS" ?
      { success: true } :
      { success: false, error: result["error"] || "Failed to authorize guest access" }
  end

  def load_client_info
    site_info = External::Unifi.get_sites(site&.controller_url, key: site&.api_key)
    site.unifi_id = site_info["data"].first["id"]
    @unifi_client = External::Unifi.get_client(site.controller_url, site.unifi_id, mac_address, key: site&.api_key)
    unless @unifi_client.nil? ||
      @unifi_client.dig("count").zero? ||
      @unifi_client.dig("data").nil? ||
      @unifi_client.dig("data").empty? ||
      @unifi_client.dig("count") > 1

      update unifi_id: @unifi_client["data"].first["id"]
    end
  end
end
