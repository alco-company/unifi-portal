require "application_system_test_case"

class ClientsTest < ApplicationSystemTestCase
  setup do
    @client = clients(:one)
  end

  test "visiting the index" do
    visit clients_url
    assert_selector "h1", text: "Clients"
  end

  test "should create client" do
    visit clients_url
    click_on "New client"

    check "Active" if @client.active
    fill_in "Email", with: @client.email
    fill_in "Guest max", with: @client.guest_max
    fill_in "Guest rx", with: @client.guest_rx
    fill_in "Guest tx", with: @client.guest_tx
    fill_in "Name", with: @client.name
    fill_in "Phone", with: @client.phone
    fill_in "Tenant", with: @client.tenant_id
    click_on "Create Client"

    assert_text "Client was successfully created"
    click_on "Back"
  end

  test "should update Client" do
    visit client_url(@client)
    click_on "Edit this client", match: :first

    check "Active" if @client.active
    fill_in "Email", with: @client.email
    fill_in "Guest max", with: @client.guest_max
    fill_in "Guest rx", with: @client.guest_rx
    fill_in "Guest tx", with: @client.guest_tx
    fill_in "Name", with: @client.name
    fill_in "Phone", with: @client.phone
    fill_in "Tenant", with: @client.tenant_id
    click_on "Update Client"

    assert_text "Client was successfully updated"
    click_on "Back"
  end

  test "should destroy Client" do
    visit client_url(@client)
    accept_confirm { click_on "Destroy this client", match: :first }

    assert_text "Client was successfully destroyed"
  end
end
