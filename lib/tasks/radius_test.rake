# lib/tasks/radius_test.rake

namespace :radius do
  desc "Test FreeRADIUS authentication without SMS/Email OTP"
  task test: :environment do
    puts "🧪 Heimdall FreeRADIUS Testing"
    puts "=" * 40
    
    # Test database connectivity
    puts "\n1. Testing database connections..."
    
    begin
      # Test main database
      puts "   Main DB: #{ActiveRecord::Base.connection.execute('SELECT 1').first}"
      
      # Test FreeRADIUS database
      freeradius_db = ActiveRecord::Base.establish_connection(
        ActiveRecord::Base.configurations.configurations
          .find { |config| config.name == 'freeradius' }&.configuration_hash ||
        Rails.application.config.database_configuration['production']['freeradius']
      )
      
      puts "   ✅ Database connections successful"
    rescue => e
      puts "   ❌ Database connection failed: #{e.message}"
      exit 1
    end
    
    # Create test data
    puts "\n2. Creating test user and client..."
    
    # Create a test tenant if none exists
    tenant = Tenant.first || Tenant.create!(
      name: "Test Tenant",
      active: true
    )
    
    # Create a test site if none exists  
    site = tenant.sites.first || tenant.sites.create!(
      name: "Test Site",
      controller_type: "radius",
      active: true
    )
    
    # Create test client (guest user)
    test_phone = "+1555#{rand(1000000..9999999)}"
    client = tenant.clients.find_or_create_by(phone: test_phone) do |c|
      c.name = "Test User"
      c.email = "test@example.com"
      c.active = true
    end
    
    # Create test device
    test_mac = "02:#{Array.new(5) { "%02x" % rand(256) }.join(':')}"
    device = client.devices.find_or_create_by(mac_address: test_mac) do |d|
      d.site = site
      d.active = true
      d.authentication_expire_at = 24.hours.from_now
    end
    
    puts "   ✅ Created test client: #{client.phone}"
    puts "   ✅ Created test device: #{device.mac_address}"
    
    # Create RADIUS user record
    puts "\n3. Creating FreeRADIUS user records..."
    
    username = client.phone.gsub(/\D/, '') # Remove non-digits for RADIUS username
    password = "testpass123"
    
    # Use raw SQL to insert into FreeRADIUS tables
    ActiveRecord::Base.connection.execute(%{
      INSERT IGNORE INTO freeradius.radcheck (username, attribute, op, value) 
      VALUES ('#{username}', 'Cleartext-Password', ':=', '#{password}')
    })
    
    ActiveRecord::Base.connection.execute(%{
      INSERT IGNORE INTO freeradius.radreply (username, attribute, op, value)
      VALUES ('#{username}', 'Session-Timeout', '=', '86400')
    })
    
    puts "   ✅ Created RADIUS user: #{username} / #{password}"
    
    # Create test NAS client
    nas = site.nas.find_or_create_by(nasname: "127.0.0.1") do |n|
      n.shortname = "test-nas"
      n.nas_type = "other"
      n.secret = "testing123" 
      n.description = "Test NAS for RADIUS validation"
    end
    
    puts "   ✅ Created NAS client: #{nas.nasname}"
    
    puts "\n4. 📋 Test Data Summary:"
    puts "   Tenant: #{tenant.name} (ID: #{tenant.id})"
    puts "   Site: #{site.name} (ID: #{site.id})"
    puts "   Client: #{client.name} (#{client.phone})"
    puts "   Device: #{device.mac_address}"
    puts "   RADIUS User: #{username}"
    puts "   RADIUS Pass: #{password}"
    puts "   NAS: #{nas.nasname} (secret: #{nas.secret})"
    
    puts "\n5. 🧪 Manual Testing Commands:"
    puts "\n   Test RADIUS authentication:"
    puts "   bin/kamal app exec --destination staging --interactive --reuse \"echo 'User-Name = \\\"#{username}\\\", User-Password = \\\"#{password}\\\"' | radclient -x 127.0.0.1:1812 auth testing123\""
    
    puts "\n   Test device authorization through Heimdall:"
    puts "   Device.find(#{device.id}).authorize"
    
    puts "\n   Check RADIUS logs:"
    puts "   bin/kamal accessory logs freeradius --destination staging -f"
    
    puts "\n   Connect to Rails console:"
    puts "   bin/kamal console --destination staging"
    
    puts "\n6. 🔍 Database Queries for Verification:"
    puts "\n   Check RADIUS user:"
    puts "   SELECT * FROM freeradius.radcheck WHERE username = '#{username}';"
    
    puts "\n   Check authentication logs:"
    puts "   SELECT * FROM freeradius.radpostauth ORDER BY authdate DESC LIMIT 10;"
    
    puts "\n   Check Heimdall device:"
    puts "   SELECT * FROM devices WHERE mac_address = '#{device.mac_address}';"
    
    puts "\n" + "=" * 40
    puts "🎯 Test setup complete! Use the commands above to validate."
  end
  
  desc "Clean up test RADIUS data"
  task cleanup: :environment do
    puts "🧹 Cleaning up test RADIUS data..."
    
    # Remove test users (those with phone numbers as usernames)
    ActiveRecord::Base.connection.execute(%{
      DELETE FROM freeradius.radcheck WHERE username REGEXP '^[0-9]+$'
    })
    
    ActiveRecord::Base.connection.execute(%{  
      DELETE FROM freeradius.radreply WHERE username REGEXP '^[0-9]+$'
    })
    
    ActiveRecord::Base.connection.execute(%{
      DELETE FROM freeradius.radpostauth WHERE username REGEXP '^[0-9]+$'
    })
    
    # Remove test NAS entries
    Nas.where(shortname: 'test-nas').destroy_all
    
    puts "✅ Test data cleaned up"
  end
  
  desc "Show current RADIUS database status"
  task status: :environment do
    puts "📊 FreeRADIUS Database Status"
    puts "=" * 30
    
    begin
      radcheck_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM freeradius.radcheck").first[0]
      radreply_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM freeradius.radreply").first[0]
      radacct_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM freeradius.radacct").first[0]
      nas_count = Nas.count
      
      puts "Users (radcheck): #{radcheck_count}"
      puts "Reply attributes (radreply): #{radreply_count}" 
      puts "Accounting records (radacct): #{radacct_count}"
      puts "NAS clients: #{nas_count}"
      
      puts "\nRecent authentication attempts:"
      recent_auth = ActiveRecord::Base.connection.execute(%{
        SELECT username, reply, authdate 
        FROM freeradius.radpostauth 
        ORDER BY authdate DESC 
        LIMIT 5
      })
      
      recent_auth.each do |row|
        puts "  #{row[2]} - #{row[0]} (#{row[1]})"
      end
      
    rescue => e
      puts "❌ Error accessing database: #{e.message}"
    end
  end
end
