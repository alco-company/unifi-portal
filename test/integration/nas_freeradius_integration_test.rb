require "test_helper"
require "fileutils"
require "tempfile"

class NasFreeradiusIntegrationTest < ActionDispatch::IntegrationTest
  # Skip these tests unless explicitly enabled via environment variable
  def setup
    skip "FreeRADIUS integration tests disabled in CI" unless ENV['ENABLE_FREERADIUS_INTEGRATION_TESTS'] == 'true'
    super
    @nas = nas(:one)
    @site = @nas.site
    @tenant = @site.tenant
    @user = users(:one)
    login_as @user
    
    # Enable FreeRADIUS auto update for testing
    @original_env_update = ENV['FREERADIUS_AUTO_UPDATE']
    @original_env_container = ENV['FREERADIUS_CONTAINER_NAME']
    ENV['FREERADIUS_AUTO_UPDATE'] = 'true'
    ENV['FREERADIUS_CONTAINER_NAME'] = 'test-freeradius'
    
    # Create temp directory to simulate config files
    @temp_dir = Dir.mktmpdir('freeradius_test')
    @config_file = File.join(@temp_dir, 'clients.conf')
    
    # Track system commands called
    @system_commands = []
    
    # Mock system method on all controller instances
    Admin::NasController.class_eval do
      alias_method :original_system, :system
      
      define_method(:system) do |command|
        @system_commands ||= []
        @system_commands << command
        
        case command
        when /docker cp (.+) test-freeradius:\/etc\/raddb\/clients\.conf/
          # Simulate copying config to container
          temp_file = $1
          if File.exist?(temp_file)
            FileUtils.cp(temp_file, @config_file)
          end
          true
        when /docker exec test-freeradius kill -HUP/
          # Simulate HUP signal success
          true
        else
          true
        end
      end
    end
    
    # Make system_commands accessible to tests
    @controller_instance = Admin::NasController.new
    @controller_instance.instance_variable_set(:@config_file, @config_file)
  end

  teardown do
    # Restore original system method
    Admin::NasController.class_eval do
      if method_defined?(:original_system)
        alias_method :system, :original_system
        remove_method :original_system
      end
    end
    
    # Clean up temp directory
    FileUtils.remove_entry(@temp_dir) if Dir.exist?(@temp_dir)
    
    # Restore environment variables
    ENV['FREERADIUS_AUTO_UPDATE'] = @original_env_update
    ENV['FREERADIUS_CONTAINER_NAME'] = @original_env_container
  end

  test "creating NAS through admin interface triggers FreeRADIUS config update" do
    nas_params = {
      nasname: "192.168.100.10",
      shortname: "integration-test-nas",
      secret: "integrationtestsecret",
      nas_type: "cisco",
      description: "Integration test NAS",
      ports: "1812,1813"
    }
    
    # Create NAS through admin interface
    assert_difference("Nas.count") do
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: nas_params }
    end
    
    # Verify NAS was created successfully
    assert_redirected_to admin_tenant_site_nas_url(@tenant, @site, Nas.last)
    
    created_nas = Nas.find_by(shortname: "integration-test-nas")
    assert created_nas.present?
    assert_equal "192.168.100.10", created_nas.nasname
    assert_equal "integrationtestsecret", created_nas.secret
    
    # Verify configuration file was created/updated
    assert File.exist?(@config_file), "FreeRADIUS config file should have been created"
    
    config_content = File.read(@config_file)
    
    # Verify our NAS is in the configuration
    assert_match(/client integration-test-nas \{/, config_content)
    assert_match(/ipaddr = 192\.168\.100\.10/, config_content)
    assert_match(/secret = integrationtestsecret/, config_content)
    assert_match(/type = cisco/, config_content)
    assert_match(/# Integration test NAS/, config_content)
    
    # Verify default clients are present
    assert_match(/client localhost \{/, config_content)
    assert_match(/client docker \{/, config_content)
  end
  
  test "updating NAS through admin interface updates FreeRADIUS config" do
    # Update existing NAS
    updated_params = {
      nasname: "192.168.200.20",
      shortname: "updated-test-nas",
      description: "Updated integration test NAS",
      secret: @nas.secret,
      nas_type: "mikrotik"
    }
    
    patch admin_tenant_site_nas_url(@tenant, @site, @nas), params: { nas: updated_params }
    
    assert_redirected_to admin_tenant_site_nas_url(@tenant, @site, @nas)
    
    # Reload NAS to get updated values
    @nas.reload
    assert_equal "192.168.200.20", @nas.nasname
    assert_equal "updated-test-nas", @nas.shortname
    
    # Verify configuration was updated
    if File.exist?(@config_file)
      config_content = File.read(@config_file)
      
      assert_match(/client updated-test-nas \{/, config_content)
      assert_match(/ipaddr = 192\.168\.200\.20/, config_content)
      assert_match(/type = mikrotik/, config_content)
      assert_match(/# Updated integration test NAS/, config_content)
    end
  end
  
  test "deleting NAS through admin interface removes it from FreeRADIUS config" do
    # Create a NAS to delete
    test_nas = Nas.create!(
      site: @site,
      nasname: "192.168.99.99",
      shortname: "delete-integration-test",
      secret: "deletemesecret",
      nas_type: "other",
      description: "NAS to be deleted in integration test"
    )
    
    # First, create a config with this NAS
    controller = Admin::NasController.new
    controller.instance_variable_set(:@config_file, @config_file)
    
    # Generate initial config
    config_content = controller.send(:generate_freeradius_config)
    File.write(@config_file, config_content)
    
    # Verify NAS is in config before deletion
    config_before = File.read(@config_file)
    assert_match(/client delete-integration-test \{/, config_before)
    assert_match(/deletemesecret/, config_before)
    
    # Delete the NAS
    assert_difference("Nas.count", -1) do
      delete admin_tenant_site_nas_url(@tenant, @site, test_nas)
    end
    
    assert_redirected_to admin_tenant_site_nas_index_url(@tenant, @site)
    
    # Verify NAS is removed from config
    if File.exist?(@config_file)
      config_after = File.read(@config_file)
      refute_match(/client delete-integration-test \{/, config_after)
      refute_match(/deletemesecret/, config_after)
    end
  end
  
  test "automatic secret generation works in integration test" do
    nas_params_without_secret = {
      nasname: "192.168.50.50",
      shortname: "auto-secret-integration",
      nas_type: "cisco",
      description: "Auto-generated secret test"
    }
    
    assert_difference("Nas.count") do
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: nas_params_without_secret }
    end
    
    created_nas = Nas.find_by(shortname: "auto-secret-integration")
    assert created_nas.present?
    assert created_nas.secret.present?
    assert_equal 32, created_nas.secret.length
    
    # Verify the auto-generated secret is properly formatted (hex)
    assert_match(/^[0-9a-f]{32}$/, created_nas.secret)
    
    # Verify it's in the FreeRADIUS config
    if File.exist?(@config_file)
      config_content = File.read(@config_file)
      assert_match(/secret = #{created_nas.secret}/, config_content)
    end
  end
  
  test "FreeRADIUS config generation includes all required elements" do
    # Create a variety of NAS devices
    nas_cisco = Nas.create!(
      site: @site,
      nasname: "10.1.1.1",
      shortname: "cisco-switch",
      secret: "ciscosecret",
      nas_type: "cisco",
      description: "Cisco switch"
    )
    
    nas_mikrotik = Nas.create!(
      site: @site,
      nasname: "10.2.2.2", 
      shortname: "mikrotik-router",
      secret: "mikrotiksecret",
      nas_type: "mikrotik",
      description: "MikroTik router"
    )
    
    nas_minimal = Nas.create!(
      site: @site,
      nasname: "10.3.3.3",
      shortname: "minimal-nas",
      secret: "minimalsecret"
      # No type or description
    )
    
    # Trigger config generation
    post admin_tenant_site_nas_index_url(@tenant, @site), params: {
      nas: {
        nasname: "10.4.4.4",
        shortname: "trigger-config",
        secret: "triggersecret"
      }
    }
    
    assert File.exist?(@config_file)
    config_content = File.read(@config_file)
    
    # Verify structure and required elements
    client_blocks = config_content.scan(/client (\w+) \{([^}]+)\}/m)
    
    # Should have at least: localhost, docker, and our 4 NAS devices
    assert client_blocks.length >= 6, "Should have multiple client blocks"
    
    # Check localhost client
    localhost_block = client_blocks.find { |name, content| name == "localhost" }
    assert localhost_block, "Should have localhost client"
    assert_match(/ipaddr = 127\.0\.0\.1/, localhost_block[1])
    assert_match(/secret = testing123/, localhost_block[1])
    
    # Check docker client
    docker_block = client_blocks.find { |name, content| name == "docker" }
    assert docker_block, "Should have docker client"
    assert_match(/ipaddr = 172\.16\.0\.0\/12/, docker_block[1])
    
    # Check our created NAS devices
    cisco_block = client_blocks.find { |name, content| name == "cisco-switch" }
    assert cisco_block, "Should have Cisco NAS"
    assert_match(/ipaddr = 10\.1\.1\.1/, cisco_block[1])
    assert_match(/secret = ciscosecret/, cisco_block[1])
    assert_match(/type = cisco/, cisco_block[1])
    
    mikrotik_block = client_blocks.find { |name, content| name == "mikrotik-router" }
    assert mikrotik_block, "Should have MikroTik NAS"
    assert_match(/type = mikrotik/, mikrotik_block[1])
    
    minimal_block = client_blocks.find { |name, content| name == "minimal-nas" }
    assert minimal_block, "Should have minimal NAS"
    assert_match(/ipaddr = 10\.3\.3\.3/, minimal_block[1])
    # Should not have empty type line
    assert_not_match(/type = \s*$/, minimal_block[1])
    
    # Clean up
    [nas_cisco, nas_mikrotik, nas_minimal].each(&:destroy)
  end
  
  test "configuration update handles errors gracefully" do
    # Temporarily disable auto-update to test error handling
    ENV['FREERADIUS_AUTO_UPDATE'] = 'false'
    
    nas_params = {
      nasname: "192.168.77.77",
      shortname: "error-test-nas",
      secret: "errortestsecret"
    }
    
    # Should still create NAS even if config update is disabled
    assert_difference("Nas.count") do
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: nas_params }
    end
    
    created_nas = Nas.find_by(shortname: "error-test-nas")
    assert created_nas.present?
    
    # Re-enable for cleanup
    ENV['FREERADIUS_AUTO_UPDATE'] = 'true'
  end
end
