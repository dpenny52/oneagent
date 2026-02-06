defmodule OneAgentWeb.UserSessionControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.AccountsFixtures

  setup %{conn: conn} do
    user = confirmed_user_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: user}
  end

  describe "POST /api/auth/login" do
    test "logs the user in and returns token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert %{"data" => %{"user" => user_data, "token" => token}} = json_response(conn, 200)
      assert user_data["email"] == user.email
      assert is_binary(token)
    end

    test "returns error with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "user" => %{"email" => user.email, "password" => "wrong-password!"}
        })

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end

    test "returns error with non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "user" => %{"email" => "nobody@example.com", "password" => "doesntmatter!"}
        })

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/magic-link" do
    test "always returns success message (user enumeration prevention)", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/magic-link", %{
          "user" => %{"email" => user.email}
        })

      assert %{"data" => %{"message" => msg}} = json_response(conn, 200)
      assert msg =~ "magic link"
    end

    test "returns same response for non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/magic-link", %{
          "user" => %{"email" => "nobody@example.com"}
        })

      assert %{"data" => %{"message" => msg}} = json_response(conn, 200)
      assert msg =~ "magic link"
    end
  end

  describe "POST /api/auth/magic-link/verify" do
    test "returns user and token for valid magic link", %{conn: conn, user: user} do
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/api/auth/magic-link/verify", %{"token" => encoded_token})

      assert %{"data" => %{"user" => user_data, "token" => token}} = json_response(conn, 200)
      assert user_data["email"] == user.email
      assert is_binary(token)
    end

    test "returns error for invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/magic-link/verify", %{"token" => "invalid"})

      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "DELETE /api/auth/logout" do
    setup :register_and_log_in_user

    test "logs the user out", %{conn: conn} do
      conn = delete(conn, ~p"/api/auth/logout")
      assert %{"data" => %{"message" => "Logged out successfully."}} = json_response(conn, 200)
    end
  end

  describe "GET /api/auth/me" do
    setup :register_and_log_in_user

    test "returns current user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/auth/me")
      assert %{"data" => %{"user" => user_data}} = json_response(conn, 200)
      assert user_data["email"] == user.email
      assert user_data["id"] == user.id
    end

    test "returns 401 without auth", %{conn: _conn} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/auth/password" do
    setup :register_and_log_in_user

    test "updates password and returns new token", %{conn: conn} do
      conn =
        put(conn, ~p"/api/auth/password", %{
          "current_password" => valid_user_password(),
          "user" => %{"password" => "new_valid_password!"}
        })

      assert %{"data" => %{"user" => _, "token" => token}} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "returns error with wrong current password", %{conn: conn} do
      conn =
        put(conn, ~p"/api/auth/password", %{
          "current_password" => "wrong-password!",
          "user" => %{"password" => "new_valid_password!"}
        })

      assert %{"error" => "Current password is incorrect"} = json_response(conn, 401)
    end
  end
end
