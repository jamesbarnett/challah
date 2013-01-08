require 'helper'

class UserTest < ActiveSupport::TestCase
  should validate_presence_of :email
  should validate_presence_of :first_name
  should validate_presence_of :last_name

  context "With an existing user" do
    setup do
      create(:user)
    end

    should validate_uniqueness_of :email
  end

  context "A User class" do
    should "find a user by username or email" do
      user_one = build(:user, :username => ' Test-user ', :email => 'tester@example.com')
      user_two = build(:user, :username => 'test-user-2  ', :email => 'tester2@example.com')

      user_one.password!('test123')
      user_two.password!('test123')

      user_one.save
      user_two.save

      assert_equal user_one, ::User.find_for_session('test-user')
      assert_equal user_one, ::User.find_for_session('tester@example.com')

      assert_equal user_one, ::User.find_for_session('Test-user')
      assert_equal user_one, ::User.find_for_session('tester@example.com')

      assert_equal user_two, ::User.find_for_session('test-user-2')
      assert_equal user_two, ::User.find_for_session('tester2@example.com')

      assert_equal nil, ::User.find_for_session(' ')
      assert_equal nil, ::User.find_for_session('not-existing')
    end
  end

  context "A user instance" do
    should "have a name attribute that returns the full name" do
      user = ::User.new

      user.stubs(:first_name).returns('Cal')
      user.stubs(:last_name).returns('Ripken')

      assert_equal "Cal Ripken", user.name
      assert_equal "Cal R.", user.small_name
    end

    should "have an active? user flag" do
      user = ::User.new

      user.active = true
      assert_equal true, user.active
      assert_equal true, user.active?
      assert_equal true, user.valid_session?

      user.active = false
      assert_equal false, user.active
      assert_equal false, user.active?
      assert_equal false, user.valid_session?
    end

    should "not allow updating of certain protected attributes" do
      user = create(:user, :first_name => 'Old', :last_name => 'Nombre')

      assert_equal false, user.new_record?

      assert_equal 0, user.created_by
      assert_equal 'Old Nombre', user.name

      assert_raise ActiveModel::MassAssignmentSecurity::Error do
        user.update_attributes({
          :created_by => 1,
          :first_name => 'New',
          :last_name => 'Name'
        })
      end

      assert_equal 0, user.created_by
    end

    should "create a user with password and authenticate them" do
      user = build(:user)

      user.password = 'abc123'
      user.password_confirmation = 'abc123'
      assert_equal 'abc123', user.password

      assert user.save

      assert_equal true, user.provider?(:password)
      assert_not_nil user.provider(:password)

      assert_equal true, user.authenticate('abc123')
      assert_equal true, user.authenticate(:password, 'abc123')
      assert_equal false, user.authenticate('test123')
    end

    should "be able to update a user without changing their password" do
      user = build(:user)
      user.password!('abc123')
      user.save

      assert_equal true, user.authenticate('abc123')

      user.first_name = 'New'
      user.password = ''
      user.password_confirmation = ''
      assert user.save

      assert_equal 'New', user.first_name
      assert_equal true, user.authenticate('abc123')
    end

    should "validate a password" do
      user = build(:user)
      user.password!('abc123')
      assert_equal true, user.valid?

      user.username = 'user123'
      user.password = ''
      user.password_confirmation = ''
      assert_equal false, user.valid?
      assert user.errors.full_messages.include?("Password can't be blank")

      user.password = 'abc'
      user.password_confirmation = 'abc'
      assert_equal false, user.valid?
      assert user.errors.full_messages.include?("Password is not a valid password. Please enter at least 4 letters or numbers.")

      user.password = 'abc456'
      user.password_confirmation = 'abc123'
      assert_equal false, user.valid?
      assert user.errors.full_messages.include?("Password does not match the confirmation password.")
    end

    should "create a password without confirmation when using !" do
      user = build(:user)
      user.password!('holla')
      assert_equal true, user.valid?
    end

    should "reasonable validate an email address" do
      user = build(:user)

      user.email = 'john@challah.me'
      assert_equal true, user.valid?

      user.email = 'john@challah.m@me.e'
      assert_equal false, user.valid?
    end

    should "always lower case a username when setting" do
      user = build(:user)
      user.username = 'JimBob'
      assert_equal 'jimbob', user.username
    end

    should "not authenticate with a password if none is given" do
      user = create(:user)
      assert_equal false, user.authenticate_with_password('abc123')
    end

    should "authenticate through various means by default" do
      user = build(:user)
      user.password!('abc123')
      user.save

      # By password
      assert_equal false, user.authenticate_with_password('test123')
      assert_equal false, user.authenticate(:password, 'test123')
      assert_equal false, user.authenticate('test123')

      assert_equal true, user.authenticate_with_password('abc123')
      assert_equal true, user.authenticate(:password, 'abc123')
      assert_equal true, user.authenticate('abc123')

      # By api key
      user.stubs(:api_key).returns('this-is-my-api-key')

      assert_equal true, user.authenticate_with_api_key('this-is-my-api-key')
      assert_equal true, user.authenticate_with_api_key('this-is-my-api-key')

      assert_equal false, user.authenticate_with_api_key('this-is-not-my-api-key')
      assert_equal false, user.authenticate_with_api_key('this-is-not-my-api-key')

      # With an unknown authentication method
      assert_equal false, user.authenticate(:blah, 'sdsd', 'sdlsk')
    end

    should "be able to change a username" do
      user = create(:user)

      user.password!('test123')
      user.username = 'john'
      user.save

      # reload
      user = User.find_by_id(user.id)

      assert_equal true, user.authenticate('test123')
      assert_equal 'john', user.username

      user.username = 'johndoe'
      user.save

      # reload
      user = User.find_by_id(user.id)

      assert_equal true, user.authenticate('test123')
      assert_equal 'johndoe', user.username
    end

    should "have successful and failed authentication methods" do
      user = create(:user)

      assert_nil user.last_session_ip
      assert_nil user.last_session_at

      assert_difference 'user.session_count', 1 do
        user.successful_authentication!('192.168.0.1')
      end

      assert_not_nil user.last_session_ip
      assert_not_nil user.last_session_at

      assert_difference 'user.failed_auth_count', 1 do
        user.failed_authentication!
      end
    end

    should "calculate an email hash on save" do
      user = build(:user)

      user.email = 'tester@challah.me'
      assert user.save
      assert_equal '859ea8a4ea69b321df4992ca14c08d6b', user.email_hash

      user.email = 'tester-too@challah.me'
      assert user.save
      assert_equal '45ab23dd8eb9a00f61cef27004b38b01', user.email_hash
    end

    should "have custom authorization providers" do
      user = create(:user)

      auth = Authorization.set({
        :user_id => user.id,
        :provider => 'custom',
        :uid => '12345',
        :token => 'abcdef1234569'
      })

      assert_equal false, user.provider?(:password)
      assert_equal nil, user.provider(:password)

      expected_auth = {
        :id => auth.id,
        :uid => '12345',
        :token => 'abcdef1234569'
      }

      assert_equal true, user.provider?(:custom)
      assert_equal true, user.custom_provider?

      assert_equal expected_auth, user.provider(:custom)
      assert_equal expected_auth, user.custom_provider
    end

    should "have default method_missing when not looking for a provider" do
      user = create(:user)
      assert_equal false, user.custom_provider?

      assert_raise NoMethodError do
        user.does_not_exist?
      end
    end

    should "clear authorizations when removing a user" do
      user = create(:user)

      Authorization.set({
        :user_id => user.id,
        :provider => 'custom',
        :uid => '12345',
        :token => 'abcdef1234569'
      })

      user.password!('test123')
      user.save

      assert_difference 'User.count', -1 do
        assert_difference 'Authorization.count', -2 do
          user.destroy
        end
      end
    end

    should "set provider attributes" do
      user = build(:user)

      user.provider_attributes = {
        :fake => { :uid => "1", "token" => 'me' }
      }

      assert_equal true, user.provider?(:fake)
      assert_equal true, user.valid_provider?(:fake)

      assert_difference [ 'User.count', 'Authorization.count' ], 1 do
        assert user.save
      end
    end

    should "not add invalid providers" do
      provider_attributes = {
        "fake" => { :uid => "1", "token" => 'not-me' }
      }

      user = build(:user, :provider_attributes => provider_attributes)

      assert_equal true, user.provider?(:fake)
      assert_equal false, user.valid_provider?(:fake)

      assert_difference [ 'User.count' ], 1 do
        assert_no_difference [ 'Authorization.count' ] do
          assert user.save
        end
      end
    end
  end
end