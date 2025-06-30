class Client < ApplicationRecord
  belongs_to :tenant
  has_many :devices, dependent: :destroy
  has_many :sites, through: :devices
end
