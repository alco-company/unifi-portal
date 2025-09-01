require "test_helper"
require "csv"

class Admin::CsvImportTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    @user = users(:one)
    @tenant.update!(active: true)
    
    post admin_login_path, params: { email: @user.email, password: "secret" }
  end

  test "should import clients from valid CSV file" do
    csv_content = generate_csv([
      ["John Doe", "john@example.com", "12345678", "VIP client", "1000", "5000", "10000", "true"],
      ["Jane Smith", "jane@example.com", "87654321", "Regular client", "500", "2000", "4000", "true"],
      ["Bob Johnson", "", "11111111", "Phone only", "", "", "", "false"]
    ])
    
    csv_file = create_csv_file(csv_content)
    
    assert_difference("Client.count", 3) do
      post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    assert_redirected_to admin_tenant_clients_path(@tenant)
    assert_match(/Clients imported successfully/, flash[:notice])
    
    # Verify client data
    john = Client.find_by(email: "john@example.com")
    assert_equal "John Doe", john.name
    assert_equal "12345678", john.phone
    assert_equal "VIP client", john.note
    assert_equal 1000, john.guest_max
    assert_equal 5000, john.guest_rx
    assert_equal 10000, john.guest_tx
    assert john.active?
    
    jane = Client.find_by(email: "jane@example.com")
    assert_equal "Jane Smith", jane.name
    assert jane.active?
    
    bob = Client.find_by(phone: "11111111")
    assert_equal "Bob Johnson", bob.name
    assert_nil bob.email
    assert_not bob.active?
  end

  test "should handle CSV with missing required fields" do
    csv_content = generate_csv([
      ["John Doe", "", "", "Missing email and phone", "", "", "", ""]
    ])
    
    csv_file = create_csv_file(csv_content)
    
    # Should skip rows without email AND phone
    assert_no_difference("Client.count") do
    post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    assert_redirected_to admin_tenant_clients_path(@tenant)
  end

  test "should handle empty CSV file" do
    csv_content = ""
    csv_file = create_csv_file(csv_content)
    
    assert_no_difference("Client.count") do
      post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    assert_redirected_to admin_tenant_clients_path(@tenant)
    assert_match(/CSV file is empty/, flash[:alert])
  end

  test "should require file parameter" do
    assert_no_difference("Client.count") do
      post import_admin_tenant_clients_path(@tenant), params: {}
    end
    
    assert_redirected_to admin_tenant_clients_path(@tenant)
    assert_match(/Please select a CSV file/, flash[:alert])
  end

  test "should handle CSV with special characters and formatting" do
    csv_content = generate_csv([
      ["Åse Ørsted", "åse@example.com", "+45 12 34 56 78", "Special chars æøå", "", "", "", "true"],
      ["  John Doe  ", "JOHN@EXAMPLE.COM", " 12345678 ", "Whitespace test", "", "", "", "true"]
    ])
    
    csv_file = create_csv_file(csv_content)
    
    assert_difference("Client.count", 2) do
      post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    # Check formatting
    ase = Client.find_by(email: "åse@example.com")
    assert_equal "Åse Ørsted", ase.name
    assert_equal "4512345678", ase.phone # Spaces removed
    
    john = Client.find_by(email: "john@example.com")
    assert_equal "John Doe", john.name # Titleized and trimmed
    assert_equal "12345678", john.phone # Trimmed
  end

  test "should handle CSV with boolean values" do
    csv_content = generate_csv([
      ["Active True", "active1@example.com", "11111111", "", "", "", "", "true"],
      ["Active False", "active2@example.com", "22222222", "", "", "", "", "false"],
      ["Active Yes", "active3@example.com", "33333333", "", "", "", "", "yes"],
      ["Active No", "active4@example.com", "44444444", "", "", "", "", "no"],
      ["Active 1", "active5@example.com", "55555555", "", "", "", "", "1"],
      ["Active 0", "active6@example.com", "66666666", "", "", "", "", "0"],
      ["Active Empty", "active7@example.com", "77777777", "", "", "", "", ""]
    ])
    
    csv_file = create_csv_file(csv_content)
    
    assert_difference("Client.count", 7) do
      post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    assert Client.find_by(email: "active1@example.com").active?
    assert_not Client.find_by(email: "active2@example.com").active?
    assert Client.find_by(email: "active3@example.com").active?
    assert_not Client.find_by(email: "active4@example.com").active?
    assert Client.find_by(email: "active5@example.com").active?
    assert_not Client.find_by(email: "active6@example.com").active?
    assert Client.find_by(email: "active7@example.com").active? # Default to true
  end

  test "should associate imported clients with correct tenant" do
    csv_content = generate_csv([
      ["Test User", "test@example.com", "12345678", "", "", "", "", "true"]
    ])
    
    csv_file = create_csv_file(csv_content)
    
    assert_difference("Client.count", 1) do
      post import_admin_tenant_clients_path(@tenant), params: { file: csv_file }
    end
    
    client = Client.find_by(email: "test@example.com")
    assert_equal @tenant, client.tenant
  end

  private

  def generate_csv(rows)
    CSV.generate(col_sep: ";") do |csv|
      csv << ["name", "email", "phone", "note", "guest_max", "guest_rx", "guest_tx", "active"]
      rows.each { |row| csv << row }
    end
  end

  def create_csv_file(content)
    # Create a unique test fixture file for each test
    filename = "test_clients_#{SecureRandom.hex(8)}.csv"
    fixture_file = Rails.root.join('test', 'fixtures', 'files', filename)
    File.write(fixture_file, content)
    
    # Use fixture_file_upload for proper multipart form simulation
    fixture_file_upload(filename, 'text/csv')
  end
end
