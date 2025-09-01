require "test_helper"

class Admin::NasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @nas = nas(:one)
    @site = @nas.site
    @tenant = @site.tenant
    login_as users(:one)
  end

  test "should get index" do
    get admin_tenant_site_nas_index_url(@tenant, @site)
    assert_response :success
  end

  test "should get new" do
    get new_admin_tenant_site_nas_url(@tenant, @site)
    assert_response :success
  end

  test "should create nas" do
    assert_difference("Nas.count") do
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: { community: @nas.community, description: @nas.description, nasname: "192.168.1.123", ports: @nas.ports, secret: @nas.secret, server: @nas.server, shortname: "unique-nas-test", nas_type: @nas.nas_type, site_id: @site.id } }
    end
    assert_redirected_to admin_tenant_site_nas_url(@tenant, @site, Nas.last)
  end

  test "should show nas" do
    get admin_tenant_site_nas_url(@tenant, @site, @nas)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_tenant_site_nas_url(@tenant, @site, @nas)
    assert_response :success
  end

  test "should update nas" do
    patch admin_tenant_site_nas_url(@tenant, @site, @nas), params: { nas: { community: @nas.community, description: @nas.description, nasname: @nas.nasname, ports: @nas.ports, secret: @nas.secret, server: @nas.server, shortname: @nas.shortname, site_id: @nas.site_id, nas_type: @nas.nas_type } }
    assert_redirected_to admin_tenant_site_nas_url(@tenant, @site, @nas)
  end

  test "should destroy nas" do
    assert_difference("Nas.count", -1) do
      delete admin_tenant_site_nas_url(@tenant, @site, @nas)
    end

    assert_redirected_to admin_tenant_site_nas_index_url(@tenant, @site)
  end

  test "automatic secret generation on create" do
    nas_params = {
      nasname: "192.168.1.150",
      shortname: "auto-secret-nas",
      nas_type: "cisco"
      # No secret provided - should be auto-generated
    }
    
    assert_difference("Nas.count") do
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: nas_params }
    end
    
    created_nas = Nas.find_by(shortname: "auto-secret-nas")
    assert created_nas.present?
    assert created_nas.secret.present?
    assert_equal 32, created_nas.secret.length # SecureRandom.hex(16) = 32 chars
  end

  # Tests for FreeRADIUS configuration generation
  class FreeRadiusConfigTest < Admin::NasControllerTest
    setup do
      # Clear any existing NAS entries for clean tests
      Nas.delete_all
      
      # Create test NAS entries with different characteristics
      @cisco_nas = Nas.create!(
        site: @site,
        nasname: "192.168.1.10",
        shortname: "cisco-switch",
        nas_type: "cisco",
        secret: "cisco-secret-123",
        description: "Main Cisco switch"
      )
      
      @unifi_nas = Nas.create!(
        site: @site,
        nasname: "192.168.1.20",
        shortname: "unifi-ap",
        nas_type: "unifi",
        secret: "unifi-secret-456"
      )
      
      @generic_nas = Nas.create!(
        site: @site,
        nasname: "access-point.example.com",
        shortname: "generic-ap",
        secret: "generic-secret-789",
        nas_type: "" # Explicitly set to blank to test no-type case
      )
      
      # Set @nas for any tests that might need it
      @nas = @cisco_nas
    end

    test "generate_freeradius_config includes localhost client" do
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      assert_includes config, "client localhost {"
      assert_includes config, "ipaddr = 127.0.0.1"
      assert_includes config, "secret = testing123"
      assert_includes config, "require_message_authenticator = no"
    end

    test "generate_freeradius_config includes docker network client" do
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      assert_includes config, "client docker {"
      assert_includes config, "ipaddr = 172.16.0.0/12"
      assert_includes config, "secret = testing123"
      assert_includes config, "require_message_authenticator = no"
    end

    test "generate_freeradius_config includes all NAS clients with required fields" do
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      # Test Cisco NAS
      assert_includes config, "client cisco-switch {"
      assert_includes config, "ipaddr = 192.168.1.10"
      assert_includes config, "secret = cisco-secret-123"
      assert_includes config, "require_message_authenticator = yes"
      assert_includes config, "shortname = cisco-switch"
      assert_includes config, "type = cisco"
      assert_includes config, "# Main Cisco switch"
      
      # Test UniFi NAS
      assert_includes config, "client unifi-ap {"
      assert_includes config, "ipaddr = 192.168.1.20"
      assert_includes config, "secret = unifi-secret-456"
      assert_includes config, "shortname = unifi-ap"
      assert_includes config, "type = unifi"
      
      # Test generic NAS (no type, no description)
      assert_includes config, "client generic-ap {"
      assert_includes config, "ipaddr = access-point.example.com"
      assert_includes config, "secret = generic-secret-789"
      assert_includes config, "shortname = generic-ap"
      # Should NOT include type line when nas_type is blank
      config_lines = config.split("\n")
      generic_config_start = config_lines.index { |line| line.include?("client generic-ap {") }
      generic_config_end = config_lines.index { |line| line == "}" && config_lines.index(line) > generic_config_start }
      generic_config_section = config_lines[generic_config_start..generic_config_end].join("\n")
      assert_not_includes generic_config_section, "type ="
    end

    test "generate_freeradius_config handles empty NAS list" do
      Nas.delete_all
      
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      # Should still include default clients
      assert_includes config, "client localhost {"
      assert_includes config, "client docker {"
      
      # Should not include any custom NAS clients
      assert_not_includes config, "client cisco-switch {"
      assert_not_includes config, "client unifi-ap {"
      assert_not_includes config, "client generic-ap {"
    end

    test "generate_freeradius_config escapes special characters in descriptions" do
      special_nas = Nas.create!(
        site: @site,
        nasname: "192.168.1.99",
        shortname: "special-nas",
        secret: "special-secret",
        description: "NAS with # special & chars $ and @ symbols"
      )
      
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      assert_includes config, "client special-nas {"
      assert_includes config, "# NAS with # special & chars $ and @ symbols"
    end

    test "generate_freeradius_config with very long NAS list" do
      # Create many NAS entries to test performance and correctness
      100.times do |i|
        Nas.create!(
          site: @site,
          nasname: "192.168.2.#{i + 1}",
          shortname: "nas-#{i + 1}",
          secret: "secret-#{i + 1}",
          nas_type: i.even? ? "cisco" : "unifi"
        )
      end
      
      controller = Admin::NasController.new
      config = controller.send(:generate_freeradius_config)
      
      # Should include all NAS entries plus defaults
      assert_includes config, "client localhost {"
      assert_includes config, "client docker {"
      assert_includes config, "client nas-1 {"
      assert_includes config, "client nas-50 {"
      assert_includes config, "client nas-100 {"
      
      # Count number of client blocks (should be 2 defaults + original 3 + new 100)
      client_count = config.scan(/^client /).length
      assert_equal 105, client_count
    end
  end

end
