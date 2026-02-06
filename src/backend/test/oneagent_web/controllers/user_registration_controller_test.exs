defmodule OneAgentWeb.UserRegistrationControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.AccountsFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/auth/register" do
    test "creates user and returns token", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/api/auth/register", %{
          "user" => %{"email" => email, "password" => valid_user_password()}
        })

      assert %{"data" => %{"user" => user_data, "token" => token}} = json_response(conn, 201)
      assert user_data["email"] == email
      assert is_binary(token)
    end

    test "returns errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          "user" => %{"email" => "invalid", "password" => "short"}
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["email"]
      assert errors["password"]
    end

    test "returns error for duplicate email", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/auth/register", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
    end
  end
end
