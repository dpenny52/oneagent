defmodule OneAgent.AccountsTest do
  use OneAgent.DataCase

  alias OneAgent.Accounts

  import OneAgent.AccountsFixtures
  alias OneAgent.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: valid_user_password()})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: valid_user_password()})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates password length" do
      {:error, changeset} = Accounts.register_user(%{email: unique_user_email(), password: "short"})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email, password: valid_user_password()})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with email and password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(%{email: email, password: valid_user_password()})
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "create_user_api_token/1 and fetch_user_by_api_token/1" do
    test "creates and fetches user by API token" do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)
      assert is_binary(token)
      assert {:ok, fetched_user} = Accounts.fetch_user_by_api_token(token)
      assert fetched_user.id == user.id
    end

    test "returns error for invalid token" do
      assert :error = Accounts.fetch_user_by_api_token("invalid-token")
    end
  end

  describe "delete_user_api_token/1" do
    test "deletes an API token" do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)
      assert :ok = Accounts.delete_user_api_token(token)
      assert :error = Accounts.fetch_user_by_api_token(token)
    end
  end

  describe "find_or_create_google_user/1" do
    test "creates a new user from google auth" do
      auth = %{
        uid: "google-uid-123",
        info: %{
          email: "googleuser@example.com",
          name: "Google User",
          image: "https://example.com/avatar.jpg"
        }
      }

      assert {:ok, user} = Accounts.find_or_create_google_user(auth)
      assert user.email == "googleuser@example.com"
      assert user.google_uid == "google-uid-123"
      assert user.display_name == "Google User"
      assert user.confirmed_at
    end

    test "returns existing user by google_uid" do
      auth = %{
        uid: "google-uid-456",
        info: %{email: "existing@example.com", name: "Existing", image: nil}
      }

      {:ok, user1} = Accounts.find_or_create_google_user(auth)
      {:ok, user2} = Accounts.find_or_create_google_user(auth)
      assert user1.id == user2.id
    end

    test "links existing email user to google account" do
      user = user_fixture(%{email: "link@example.com"})

      auth = %{
        uid: "google-link-789",
        info: %{email: "link@example.com", name: "Linked", image: "https://example.com/img.jpg"}
      }

      {:ok, linked_user} = Accounts.find_or_create_google_user(auth)
      assert linked_user.id == user.id
      assert linked_user.google_uid == "google-link-789"
    end
  end

  describe "confirm_user/1" do
    test "confirms user with valid token" do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
    end

    test "returns error with invalid token" do
      assert :error = Accounts.confirm_user("invalid-token")
    end
  end

  describe "deliver_user_reset_password_instructions/2 and reset_user_password/2" do
    test "sends token and resets password" do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      reset_user = Accounts.get_user_by_reset_password_token(token)
      assert reset_user.id == user.id

      {:ok, updated_user} = Accounts.reset_user_password(reset_user, %{password: "new_password!!"})
      assert Accounts.get_user_by_email_and_password(updated_user.email, "new_password!!")
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, {user, _expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, _token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
