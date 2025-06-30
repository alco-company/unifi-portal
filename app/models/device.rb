class Device < ApplicationRecord
  belongs_to :client
  belongs_to :site, optional: true
end
