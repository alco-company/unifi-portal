require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @client = clients(:one)
  end

  test "should get index" do
    get admin_tenant_clients_path(@client.tenant)
    assert_response :success
  end

  test "should get new" do
    get new_admin_tenant_client_path(@client.tenant)
    assert_response :success
  end

  test "should create client" do
    assert_difference("Client.count") do
      post admin_tenant_clients_path(@client.tenant), params: { client: { active: @client.active, email: @client.email, guest_max: @client.guest_max, guest_rx: @client.guest_rx, guest_tx: @client.guest_tx, name: @client.name, phone: @client.phone, tenant_id: @client.tenant_id, note: @client.note } }
    end

    assert_redirected_to admin_tenant_clients_url(@client.tenant)
  end

  test "should show client" do
    get admin_tenant_client_url(@client.tenant, @client)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_tenant_client_url(@client.tenant, @client)
    assert_response :success
  end

  test "should update client" do
    patch admin_tenant_client_url(@client.tenant, @client), params: { client: { active: @client.active, email: @client.email, guest_max: @client.guest_max, guest_rx: @client.guest_rx, guest_tx: @client.guest_tx, name: @client.name, phone: @client.phone, tenant_id: @client.tenant_id, note: @client.note } }
    assert_redirected_to admin_tenant_clients_url(@client.tenant)
  end

  test "should destroy client" do
    assert_difference("Client.count", -1) do
      delete admin_tenant_client_url(@client.tenant, @client)
    end

    assert_redirected_to admin_tenant_clients_path(@client.tenant)
  end
end
