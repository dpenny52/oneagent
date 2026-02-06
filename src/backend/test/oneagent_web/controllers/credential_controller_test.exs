defmodule OneAgentWeb.CredentialControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.CredentialsFixtures

  setup :register_and_log_in_user

  describe "GET /api/credentials" do
    test "lists credentials", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      _cred = credential_fixture(scope)

      conn = get(conn, "/api/credentials")
      assert %{"data" => [cred]} = json_response(conn, 200)
      # Ensure encrypted value is NOT exposed
      refute Map.has_key?(cred, "encrypted_value")
      refute Map.has_key?(cred, "value")
    end
  end

  describe "POST /api/credentials" do
    test "creates a credential", %{conn: conn} do
      attrs = valid_credential_attributes()
      conn = post(conn, "/api/credentials", %{"credential" => attrs})

      assert %{"data" => %{"id" => _, "name" => name}} = json_response(conn, 201)
      assert name == attrs["name"]
    end

    test "does not expose encrypted value in response", %{conn: conn} do
      attrs = valid_credential_attributes()
      conn = post(conn, "/api/credentials", %{"credential" => attrs})

      assert %{"data" => cred} = json_response(conn, 201)
      refute Map.has_key?(cred, "encrypted_value")
      refute Map.has_key?(cred, "value")
    end
  end

  describe "GET /api/credentials/:id" do
    test "shows a credential without secret", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      cred = credential_fixture(scope)

      conn = get(conn, "/api/credentials/#{cred.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == cred.id
      refute Map.has_key?(data, "encrypted_value")
    end
  end

  describe "PUT /api/credentials/:id" do
    test "updates a credential", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      cred = credential_fixture(scope)

      conn = put(conn, "/api/credentials/#{cred.id}", %{"credential" => %{"name" => "updated"}})
      assert %{"data" => %{"name" => "updated"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/credentials/:id" do
    test "deletes a credential", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      cred = credential_fixture(scope)

      conn = delete(conn, "/api/credentials/#{cred.id}")
      assert response(conn, 204)
    end
  end
end
