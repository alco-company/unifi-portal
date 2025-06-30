require "test_helper"

class Admin::SitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site = sites(:one)
  end

  test "should get index" do
    get admin_tenant_sites_url(@site.tenant)
    assert_response :success
  end

  test "should get new" do
    get new_admin_tenant_site_url(@site.tenant)
    assert_response :success
  end

  test "should create site" do
    assert_difference("Site.count") do
      post admin_tenant_sites_url(@site.tenant), params: { site: { active: @site.active, api_key: @site.api_key, controller_url: @site.controller_url, name: @site.name, ssid: @site.ssid, tenant_id: @site.tenant_id, url: @site.url } }
    end

    assert_redirected_to admin_tenant_sites_url(@site.tenant)
  end

  test "should show site" do
    get admin_tenant_site_url(@site.tenant, @site)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_tenant_site_url(@site.tenant, @site)
    assert_response :success
  end

  test "should update site" do
    patch admin_tenant_site_url(@site.tenant, @site), params: { site: { active: @site.active, api_key: @site.api_key, controller_url: @site.controller_url, name: @site.name, ssid: @site.ssid, tenant_id: @site.tenant_id, url: @site.url } }
    assert_redirected_to admin_tenant_sites_url(@site.tenant)
  end

  test "should destroy site" do
    assert_difference("Site.count", -1) do
      delete admin_tenant_site_url(@site.tenant, @site)
    end

    assert_redirected_to admin_tenant_sites_url(@site.tenant)
  end
end
