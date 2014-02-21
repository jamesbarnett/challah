require 'test_helper'

class RestrictionsControllerTest < ActionController::TestCase
  context "The restrictions controller" do
    context "With no user" do
      setup do
        signout
      end

      should "be able to get to the index page" do
        get :index
        assert_response :success
        assert_equal nil, assigns(:current_user)
      end

      should "not be able to get to the edit page" do
        get :edit
        assert_redirected_to '/sign-in'
      end
    end

    context "with a regular user" do
      setup do
        @user = create(:user)
        signin_as(@user)
      end

      should "get to the index page" do
        get :index
        assert_response :success
        assert_equal @user, assigns(:current_user)
      end

      should "get to the edit page" do
        get :edit
        assert_response :success
      end

      should "get to the show page" do
        get :show
        assert_response :success
      end
    end

    context "With an api key" do
      setup do
        @user = create(:user)
      end

      context "and api_key functionality enabled" do
        setup do
          Challah.options[:api_key_enabled] = true
        end

        should "get to the index page" do
          get :index, :key => @user.api_key
          assert_response :success
          assert_equal @user, assigns(:current_user)
        end

        should "get to the edit page" do
          get :edit, :key => @user.api_key
          assert_response :success
        end

        should "get to the show page" do
          get :show, :key => @user.api_key
          assert_response :success
        end
      end

      context "and api_key functionality disabled" do
        setup do
          Challah.options[:api_key_enabled] = false
        end

        should "get to the index page" do
          get :index, :key => @user.api_key
          assert_response :success
          assert_equal nil, assigns(:current_user)
        end

        should "not get to the edit page" do
          get :edit, :key => @user.api_key
          assert_redirected_to '/sign-in'
        end

        should "not get to the show page" do
          get :show, :key => @user.api_key
          assert_redirected_to '/sign-in'
        end
      end
    end
  end
end
