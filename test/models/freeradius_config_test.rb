require "test_helper"
require "fileutils"
require "tempfile"

class FreeradiusConfigTest < ActiveSupport::TestCase
  setup do
    @site = sites(:one)
    @tenant = @site.tenant
    
    # Create test NAS devices
    @nas1 = Nas.create!(
      site: @site,
      nasname: "192.168.1.10",
      shortname: "test-nas-1",
      secret: "secret123",
      nas_type: "cisco",
      description: "Test NAS 1",
      ports: "1812,1813"
    )
    
    @nas2 = Nas.create!(
      site: @site,
      nasname: "10.0.0.50",
      shortname: "test-nas-2", 
      secret: "anothersecret",
      nas_type: "mikrotik",
      description: "Test NAS 2"
    )
  end
  
  teardown do
    # Clean up test data
    @nas1&.destroy
    @nas2&.destroy
  end

  test "generate_freeradius_config includes default clients" do
    controller = Admin::NasController.new
    config = controller.send(:generate_freeradius_config)
    
    # Check for localhost client
    assert_match(/client localhost \{/, config)
    assert_match(/ipaddr = 127\.0\.0\.1/, config)
    assert_match(/secret = testing123/, config)
    assert_match(/require_message_authenticator = no/, config)
    
    # Check for docker client
    assert_match(/client docker \{/, config)
    assert_match(/ipaddr = 172\.16\.0\.0\/12/, config)
    assert_match(/secret = testing123/, config)
  end
  
  test "generate_freeradius_config includes all NAS devices" do
    controller = Admin::NasController.new
    config = controller.send(:generate_freeradius_config)
    
    # Check first NAS
    assert_match(/client test-nas-1 \{/, config)
    assert_match(/ipaddr = 192\.168\.1\.10/, config)
    assert_match(/secret = secret123/, config)
    assert_match(/shortname = test-nas-1/, config)
    assert_match(/type = cisco/, config)
    assert_match(/# Test NAS 1/, config)
    
    # Check second NAS
    assert_match(/client test-nas-2 \{/, config)
    assert_match(/ipaddr = 10\.0\.0\.50/, config)
    assert_match(/secret = anothersecret/, config)
    assert_match(/shortname = test-nas-2/, config)
    assert_match(/type = mikrotik/, config)
    assert_match(/# Test NAS 2/, config)
  end
  
  test "generate_freeradius_config handles NAS without type or description" do
    # Create NAS with minimal data
    minimal_nas = Nas.create!(
      site: @site,
      nasname: "1.1.1.1",
      shortname: "minimal",
      secret: "minimalsecret"
    )
    
    controller = Admin::NasController.new
    config = controller.send(:generate_freeradius_config)
    
    assert_match(/client minimal \{/, config)
    assert_match(/ipaddr = 1\.1\.1\.1/, config)
    assert_match(/secret = minimalsecret/, config)
    assert_match(/shortname = minimal/, config)
    
    # Should not include type or description lines
    refute_match(/type = $/, config) # Empty type
    refute_match(/# $/, config) # Empty description
    
    minimal_nas.destroy
  end
  
  test "config format is valid FreeRADIUS syntax" do
    controller = Admin::NasController.new
    config = controller.send(:generate_freeradius_config)
    
    # Check basic structure - every client should have opening and closing braces
    client_blocks = config.scan(/client \w+ \{(.*?)\}/m)
    assert client_blocks.any?, "Should have client blocks"
    
    # Each block should have required fields
    client_blocks.each do |block_content|
      block_text = block_content.first
      assert_match(/ipaddr = /, block_text, "Each client should have ipaddr")
      assert_match(/secret = /, block_text, "Each client should have secret")
      assert_match(/require_message_authenticator = /, block_text, "Each client should have require_message_authenticator")
    end
  end
  
  test "update_freeradius_config handles environment controls" do
    controller = Admin::NasController.new
    
    # Test with auto update disabled (default)
    ENV.delete('FREERADIUS_AUTO_UPDATE')
    result = controller.send(:update_freeradius_config)
    assert_nil result, "Should return nil when auto update is disabled"
    
    # Test with auto update enabled
    ENV['FREERADIUS_AUTO_UPDATE'] = 'true'
    ENV['FREERADIUS_CONTAINER_NAME'] = 'test-container'
    
    # Mock system calls to prevent actual Docker commands
    system_commands = []
    controller.define_singleton_method(:system) do |command|
      system_commands << command
      true # Return success
    end
    
    # Mock File operations
    temp_files_created = []
    controller.define_singleton_method(:write_temp_file) do |content|
      file_path = "/tmp/clients_test_#{SecureRandom.hex(4)}.conf"
      temp_files_created << file_path
      file_path
    end
    
    File.stub(:write, proc { |path, content| temp_files_created << path }) do
      File.stub(:delete, proc { |path| temp_files_created.delete(path) }) do
        File.stub(:exist?, proc { |path| temp_files_created.include?(path) }) do
          result = controller.send(:update_freeradius_config)
          assert result, "Should return true on successful config update"
        end
      end
    end
    
    # Verify expected system commands were called
    assert system_commands.any? { |cmd| cmd.include?("docker cp") }, "Should call docker cp"
    assert system_commands.any? { |cmd| cmd.include?("kill -HUP") }, "Should call kill -HUP"
    
    # Cleanup
    ENV.delete('FREERADIUS_AUTO_UPDATE')
    ENV.delete('FREERADIUS_CONTAINER_NAME')
  end
end
