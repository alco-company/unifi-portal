class Tenant < ApplicationRecord
  has_many :sites, dependent: :destroy
  has_many :clients, dependent: :destroy
end
