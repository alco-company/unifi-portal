require "test_helper"

class NasTest < ActiveSupport::TestCase
  test "should not save nas without nasname and secret" do
    nas = Nas.new
    assert_not nas.save, "Saved the NAS without nasname and secret"
  end

  test "should save valid nas" do
  nas = Nas.new(site: sites(:one), nasname: "192.168.1.1", secret: "supersecret")
    assert nas.save, "Could not save a valid NAS"
  end

  test "should not save nas with duplicate nasname" do
  Nas.create!(site: sites(:one), nasname: "192.168.1.1", secret: "secret1")
  nas = Nas.new(site: sites(:one), nasname: "192.168.1.1", secret: "secret2")
  assert_not nas.valid?, "NAS should be invalid due to duplicate nasname"
  assert_includes nas.errors[:nasname], "has already been taken"
  end
end
