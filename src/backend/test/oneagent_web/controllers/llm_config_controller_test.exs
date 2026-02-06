defmodule OneAgentWeb.LlmConfigControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.CredentialsFixtures

  setup :register_and_log_in_user

  describe "GET /api/llm-configs" do
    test "lists LLM configs", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      _config = llm_config_fixture(scope)

      conn = get(conn, "/api/llm-configs")
      assert %{"data" => [config]} = json_response(conn, 200)
      assert config["provider"] == "anthropic"
      # Ensure API key is NOT exposed
      refute Map.has_key?(config, "encrypted_api_key")
      refute Map.has_key?(config, "api_key")
    end
  end

  describe "POST /api/llm-configs" do
    test "creates an LLM config", %{conn: conn} do
      attrs = valid_llm_config_attributes()
      conn = post(conn, "/api/llm-configs", %{"llm_config" => attrs})

      assert %{"data" => %{"id" => _, "provider" => "anthropic"}} = json_response(conn, 201)
    end

    test "does not expose API key in response", %{conn: conn} do
      attrs = valid_llm_config_attributes()
      conn = post(conn, "/api/llm-configs", %{"llm_config" => attrs})

      assert %{"data" => data} = json_response(conn, 201)
      refute Map.has_key?(data, "encrypted_api_key")
      refute Map.has_key?(data, "api_key")
    end
  end

  describe "GET /api/llm-configs/:id" do
    test "shows an LLM config", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      config = llm_config_fixture(scope)

      conn = get(conn, "/api/llm-configs/#{config.id}")
      assert %{"data" => %{"id" => id}} = json_response(conn, 200)
      assert id == config.id
    end
  end

  describe "PUT /api/llm-configs/:id" do
    test "updates an LLM config", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      config = llm_config_fixture(scope)

      conn = put(conn, "/api/llm-configs/#{config.id}", %{"llm_config" => %{"label" => "updated"}})
      assert %{"data" => %{"label" => "updated"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/llm-configs/:id" do
    test "deletes an LLM config", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      config = llm_config_fixture(scope)

      conn = delete(conn, "/api/llm-configs/#{config.id}")
      assert response(conn, 204)
    end
  end
end
