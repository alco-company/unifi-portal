class Nas < ApplicationRecord
  belongs_to :site

  # Basic requirements for a NAS entry
  validates :nasname, presence: true, format: {
    with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z|\A[a-zA-Z0-9][a-zA-Z0-9\-\.]*[a-zA-Z0-9]\z/,
    message: "must be a valid IP address or hostname"
  }
  validates :shortname, presence: true, format: {
    with: /\A[a-zA-Z0-9][a-zA-Z0-9\-_]*[a-zA-Z0-9]\z|\A[a-zA-Z0-9]\z/,
    message: "must contain only letters, numbers, hyphens, and underscores"
  }
  validates :secret, presence: true, length: { minimum: 8 }
  validates :nasname, uniqueness: { scope: :site_id }
  validates :shortname, uniqueness: { scope: :site_id }

  # Custom validation for IP address format
  validate :validate_ip_address_format

  # Rely on DB unique index (site_id, nasname) to raise RecordNotUnique in tests
  
  private
  
  def validate_ip_address_format
    return unless nasname.present?
    
    # Check if it's a valid IPv4 address
    if nasname =~ /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/
      octets = nasname.split('.')
      unless octets.all? { |octet| octet.to_i >= 0 && octet.to_i <= 255 }
        errors.add(:nasname, "is not a valid IPv4 address")
      end
    end
    # If it's not an IP address, assume it's a hostname (already validated by format)
  end
end
