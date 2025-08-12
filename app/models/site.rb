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
end
