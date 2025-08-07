class Device < ApplicationRecord
  belongs_to :client
  belongs_to :site, optional: true

  def self.authorized?(mac_address)
    device = find_by(mac_address: mac_address)
    return false if device.nil? || device.client.nil? || !device.client.active?
    return false if device.authentication_expire_at.nil? || device.authentication_expire_at < Time.current
    eu = External::Unifi::Base.new(site: device.site)
    return eu.is_mac_authorized?(mac_address) if eu
    false
  end

  def mac_address
    read_attribute(:mac_address).downcase.strip
  end

  def unifi_id
    read_attribute(:unifi_id).presence || mac_address.gsub(/:/, "")
  end

  def unauthorize
    if site.nil?
      return false
    end
    eu = External::Unifi::Base.new(site: site)
    load_client_info(eu)
    result = eu.revoke_guest_access(mac_address)
    result[:success] ?
      { success: true } :
      result
  end

  def authorize
    if site.nil? || !client.active?
      return false
    end
    eu = External::Unifi::Base.new(site: site)
    Rails.logger.error("Authorizing device with MAC address: #{mac_address} for site: #{site.name} using eu: #{eu.inspect}")
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
      result[:success] ?
        update_client_info(eu, result) :
        result
    end
  end

  def time_limit
    val = authentication_expire_at || created_at
    val > 24.hours.from_now ? 1000000 : 1440
  end

  def load_client_info(eu)
    site_info = eu.site_info
    site.update(unifi_id: eu.get_id) if site_info
    unifi_client_id = eu.get_client_id(mac_address)
    unless unifi_client_id.nil?
      update unifi_id: unifi_client_id
    else
      guests = eu.list_guests.filter { |g| g["mac"] == mac_address }
      if guests.any?
        guests.each do |guest|
          update unifi_id: guest["id"] if guest["id"].present?
        end
        true
      else
        Rails.logger.error("ERROR: Unifi client info not found for MAC address: #{mac_address}")
        false
      end
    end
  end

  def update_client_info(eu, result)
    Rails.logger.error("Updating device info for MAC address: #{mac_address} with result: #{result.inspect}")
    if result[:data].present?
      data = result[:data]
      update(
        last_ap: data["ap_mac"],
        unifi_id: data["_id"],
        last_authenticated_at: Time.current,
        authentication_expire_at: time_limit.minutes.from_now
      )
    else
      load_client_info(eu)
    end
    Rails.logger.error("Device info updated for MAC address: #{mac_address}")
    { success: true }
  end
end
