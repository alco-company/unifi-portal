class Site < ApplicationRecord
  belongs_to :tenant
  has_many :devices, dependent: :destroy
  has_many :clients, through: :devices

  enum :controller_type, {
    login: 0,      # uses username/password
    api_key: 1     # uses API token
  }

  validates :controller_type, presence: true
end
