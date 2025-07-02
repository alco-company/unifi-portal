class Tenant < ApplicationRecord
  has_many :sites, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :devices, through: :clients, dependent: :destroy
end
