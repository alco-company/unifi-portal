class Site < ApplicationRecord
  belongs_to :tenant
  has_many :devices, dependent: :destroy
  has_many :clients, through: :devices
end
