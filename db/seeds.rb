# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
Tenant.destroy_all
tenant = Tenant.create!(
  name: "Unifi Portal Management Tenant",
  url: "https://unifi-portal.site",
  note: "This tenant is used to manage the Unifi Portal application and its users.",
  guest_max: 100,
  guest_rx: 1000,
  guest_tx: 1000,
  active: true
)
User.find_or_create_by!(email: "superuser@unifi-portal.site") do |user|
  user.tenant = tenant
  user.name = "Unifi Portal Superuser"
  user.email = "superuser@unifi-portal.site"
  user.phone = "+4597911470"
  user.password = "password"
  user.superuser = true
  user.active = true
end
