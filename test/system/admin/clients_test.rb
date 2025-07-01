require "application_system_test_case"

class Admin::ClientsTest < ApplicationSystemTestCase
  setup do
    @client = clients(:one)
  end

  test "visiting the index" do
    visit admin_tenant_clients_url(@client.tenant_id)
    assert_selector "h1", text: "Clients"
  end

  test "should create client" do
    visit admin_tenant_clients_url(@client.tenant_id)
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
    assert_selector "h1", text: "Clients"
  end

  test "should update Client" do
    visit admin_tenant_client_url(@client.tenant_id, @client)
    click_on "Edit", match: :first

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
    assert_selector "h1", text: "Clients"
  end

  test "should destroy Client" do
    visit admin_tenant_client_url(@client.tenant_id, @client)
    click_on "Delete", match: :first
    within("dialog", wait: 3) do
      click_on "Delete"
    end

    assert_text "Client was successfully destroyed"
    assert_selector "h1", text: "Clients"

  end
end
