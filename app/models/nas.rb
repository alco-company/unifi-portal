class Nas < ApplicationRecord
  belongs_to :site

  # Basic requirements for a NAS entry
  validates :nasname, presence: true
  validates :secret, presence: true
  validates :nasname, uniqueness: { scope: :site_id }

  # Rely on DB unique index (site_id, nasname) to raise RecordNotUnique in tests
end
