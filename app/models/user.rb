class User < ApplicationRecord
  has_secure_password
  belongs_to :tenant, optional: true
  validates :email, presence: true
end
