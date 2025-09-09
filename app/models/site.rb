class Site < ApplicationRecord
  belongs_to :tenant
  has_many :devices, dependent: :destroy
  has_many :clients, through: :devices
  has_many :nas, dependent: :destroy

  attr_accessor :site_unifi_id

  enum :controller_type, {
    login: 0,      # uses username/password
    api_key: 1,     # uses API token
    radius: 2     # uses RADIUS
  }

  validates :controller_type, presence: true

  after_create :generate_qr_code
  after_update :regenerate_qr_code_if_slug_changed

  def qr_code_url
    return nil unless slug.present?
    return "https://unifi-portal.site/wifi?site=#{slug}" unless Rails.env.development?
    "https://localhost:3000/wifi?site=#{slug}"
  end

  def qr_code_svg
    return nil unless qr_code_data.present?
    require "rqrcode"
    qrcode = RQRCode::QRCode.new(qr_code_data)
    qrcode.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )
  end

  private

  def generate_qr_code
    return unless slug.present?
    self.update_column(:qr_code_data, qr_code_url)
  end

  def regenerate_qr_code_if_slug_changed
    if saved_change_to_slug?
      generate_qr_code
    end
  end
end
