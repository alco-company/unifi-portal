require "application_system_test_case"
require "fileutils"
require "tempfile"

class AdminNasFreeradiusIntegrationTest < ApplicationSystemTestCase
  setup do
    @nas = nas(:one)
    @site = @nas.site
    @tenant = @site.tenant
    @user = users(:one)
    
    # Enable FreeRADIUS auto update for testing
    ENV['FREERADIUS_AUTO_UPDATE'] = 'true'
    ENV['FREERADIUS_CONTAINER_NAME'] = 'test-freeradius'
    
    # Create a temporary directory to simulate FreeRADIUS config location
    @temp_dir = Dir.mktmpdir('freeradius_test')
    @config_file = File.join(@temp_dir, 'clients.conf')
    
    # Mock the docker commands for testing
    @original_system = method(:system)
    define_singleton_method(:system) do |command|
      handle_mocked_docker_command(command)
    end
  end

  teardown do
    # Clean up temp directory
    FileUtils.remove_entry(@temp_dir) if Dir.exist?(@temp_dir)
    
    # Reset environment variables
    ENV.delete('FREERADIUS_AUTO_UPDATE')
    ENV.delete('FREERADIUS_CONTAINER_NAME')
    
    # Restore original system method
    define_singleton_method(:system, @original_system)
  end

  test "creating a NAS device updates FreeRADIUS configuration" do
    login_as(@user)
    
    visit admin_tenant_site_nas_index_path(@tenant, @site)
    assert_text "NAS Devices"
    
    click_link "New NAS"
    
    # Fill out the form
    fill_in "Nasname", with: "192.168.1.100"
    fill_in "Shortname", with: "test-nas"
    fill_in "Nas type", with: "cisco"
    fill_in "Description", with: "Test NAS device"
    fill_in "Ports", with: "1812,1813"
    fill_in "Secret", with: "testsecret123"
    
    # Submit the form
    click_button "Create Nas"
    
    # Verify the NAS was created
    assert_text "Nas was successfully created"
    assert_text "test-nas"
    assert_text "192.168.1.100"
    
    # Verify FreeRADIUS config was updated
    assert File.exist?(@config_file), "FreeRADIUS config file should exist"
    config_content = File.read(@config_file)
    
    # Check that our new NAS is in the config
    assert_match(/client test-nas \{/, config_content)
    assert_match(/ipaddr = 192\.168\.1\.100/, config_content)
    assert_match(/secret = testsecret123/, config_content)
    assert_match(/type = cisco/, config_content)
    assert_match(/# Test NAS device/, config_content)
  end

  test "updating a NAS device updates FreeRADIUS configuration" do
    login_as(@user)
    
    visit admin_tenant_site_nas_path(@tenant, @site, @nas)
    
    click_link "Edit"
    
    # Update the NAS details
    fill_in "Nasname", with: "192.168.1.200"
    fill_in "Description", with: "Updated NAS device"
    
    click_button "Update Nas"
    
    # Verify the update was successful
    assert_text "Nas was successfully updated"
    assert_text "192.168.1.200"
    assert_text "Updated NAS device"
    
    # Verify FreeRADIUS config was updated
    assert File.exist?(@config_file), "FreeRADIUS config file should exist"
    config_content = File.read(@config_file)
    
    # Check that the updated NAS is in the config
    assert_match(/ipaddr = 192\.168\.1\.200/, config_content)
    assert_match(/# Updated NAS device/, config_content)
  end

  test "deleting a NAS device updates FreeRADIUS configuration" do
    # Create a test NAS to delete
    test_nas = Nas.create!(
      site: @site,
      nasname: "192.168.1.150",
      shortname: "delete-test",
      secret: "deletesecret",
      nas_type: "other",
      description: "NAS to be deleted"
    )
    
    login_as(@user)
    
    visit admin_tenant_site_nas_path(@tenant, @site, test_nas)
    
    # Accept the confirmation dialog and delete
    accept_confirm do
      click_link "Delete"
    end
    
    # Verify the delete was successful
    assert_text "Nas was successfully destroyed"
    assert_current_path admin_tenant_site_nas_index_path(@tenant, @site)
    
    # Verify FreeRADIUS config was updated and doesn't contain the deleted NAS
    if File.exist?(@config_file)
      config_content = File.read(@config_file)
      assert_not_match(/client delete-test \{/, config_content)
      assert_not_match(/ipaddr = 192\.168\.1\.150/, config_content)
      assert_not_match(/deletesecret/, config_content)
    end
  end

  test "bulk delete updates FreeRADIUS configuration" do
    # Create multiple test NAS devices
    nas1 = Nas.create!(
      site: @site,
      nasname: "192.168.1.101",
      shortname: "bulk-test-1",
      secret: "bulksecret1",
      nas_type: "cisco"
    )
    nas2 = Nas.create!(
      site: @site,
      nasname: "192.168.1.102",
      shortname: "bulk-test-2",
      secret: "bulksecret2",
      nas_type: "cisco"
    )
    
    login_as(@user)
    
    visit admin_tenant_site_nas_index_path(@tenant, @site)
    
    # Assuming there's a "Delete All" link/button
    if page.has_link?("Delete All")
      accept_confirm do
        click_link "Delete All"
      end
      
      assert_text "All nas were successfully deleted"
      
      # Verify FreeRADIUS config was updated
      if File.exist?(@config_file)
        config_content = File.read(@config_file)
        assert_not_match(/bulk-test-1/, config_content)
        assert_not_match(/bulk-test-2/, config_content)
      end
    end
  end

  test "FreeRADIUS config includes default clients" do
    login_as(@user)
    
    # Trigger a config update by creating a NAS
    visit new_admin_tenant_site_nas_path(@tenant, @site)
    fill_in "Nasname", with: "192.168.1.50"
    fill_in "Shortname", with: "config-test"
    fill_in "Secret", with: "configsecret"
    click_button "Create Nas"
    
    # Verify the config includes default clients
    assert File.exist?(@config_file)
    config_content = File.read(@config_file)
    
    # Check for localhost client
    assert_match(/client localhost \{/, config_content)
    assert_match(/ipaddr = 127\.0\.0\.1/, config_content)
    assert_match(/secret = testing123/, config_content)
    
    # Check for docker client
    assert_match(/client docker \{/, config_content)
    assert_match(/ipaddr = 172\.16\.0\.0\/12/, config_content)
    
    # Check our created NAS is also there
    assert_match(/client config-test \{/, config_content)
    assert_match(/ipaddr = 192\.168\.1\.50/, config_content)
  end

  test "automatic secret generation works" do
    login_as(@user)
    
    visit new_admin_tenant_site_nas_path(@tenant, @site)
    
    fill_in "Nasname", with: "192.168.1.75"
    fill_in "Shortname", with: "auto-secret-test"
    fill_in "Nas type", with: "cisco"
    # Don't fill in secret - should be auto-generated
    
    click_button "Create Nas"
    
    assert_text "Nas was successfully created"
    
    # Find the created NAS and verify it has a secret
    created_nas = Nas.find_by(shortname: "auto-secret-test")
    assert created_nas.present?
    assert created_nas.secret.present?
    assert_equal 32, created_nas.secret.length # SecureRandom.hex(16) produces 32 chars
    
    # Verify the secret is in the FreeRADIUS config
    assert File.exist?(@config_file)
    config_content = File.read(@config_file)
    assert_match(/secret = #{created_nas.secret}/, config_content)
  end

  test "error handling when FreeRADIUS update fails" do
    login_as(@user)
    
    # Mock system command to fail
    define_singleton_method(:system) do |command|
      false # Simulate command failure
    end
    
    visit new_admin_tenant_site_nas_path(@tenant, @site)
    
    fill_in "Nasname", with: "192.168.1.99"
    fill_in "Shortname", with: "fail-test"
    fill_in "Secret", with: "failsecret"
    
    # The NAS should still be created even if FreeRADIUS update fails
    click_button "Create Nas"
    
    assert_text "Nas was successfully created"
    
    # Verify NAS exists in database
    created_nas = Nas.find_by(shortname: "fail-test")
    assert created_nas.present?
  end

  private

  def handle_mocked_docker_command(command)
    case command
    when /docker cp (.+) test-freeradius:\/etc\/raddb\/clients\.conf/
      # Simulate copying config to container by copying to our temp file
      temp_file = $1
      if File.exist?(temp_file)
        FileUtils.cp(temp_file, @config_file)
      end
      true
    when /docker exec test-freeradius kill -HUP/
      # Simulate HUP signal - just return success
      true
    else
      # For any other commands, return success
      true
    end
  end
end
