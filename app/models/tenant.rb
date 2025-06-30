class Tenant < ApplicationRecord
  has_many :sites, dependent: :destroy
end
