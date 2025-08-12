require "test_helper"

class Admin::NasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @nas= nas(:one)
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
      post admin_tenant_site_nas_index_url(@tenant, @site), params: { nas: { community: @nas.community, description: @nas.description, nasname: "UniqueNasName", ports: @nas.ports, secret: @nas.secret, server: @nas.server, shortname: @nas.shortname, nas_type: @nas.nas_type } }
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
end
