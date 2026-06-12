require "test_helper"

class PackageBoxesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get package_boxes_index_url
    assert_response :success
  end

  test "should get show" do
    get package_boxes_show_url
    assert_response :success
  end

  test "should get new" do
    get package_boxes_new_url
    assert_response :success
  end

  test "should get create" do
    get package_boxes_create_url
    assert_response :success
  end

  test "should get edit" do
    get package_boxes_edit_url
    assert_response :success
  end

  test "should get update" do
    get package_boxes_update_url
    assert_response :success
  end

  test "should get destroy" do
    get package_boxes_destroy_url
    assert_response :success
  end
end
