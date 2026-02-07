defmodule OneAgent.CredentialsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Credentials
  alias OneAgent.Credentials.{Credential, LlmConfig}

  import OneAgent.CredentialsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  # ── Credentials ──────────────────────────────────────────────

  describe "list_credentials/1" do
    test "returns credentials for the given user", %{scope: scope} do
      cred = credential_fixture(scope)
      assert [listed] = Credentials.list_credentials(scope)
      assert listed.id == cred.id
    end

    test "does not return credentials from other users", %{scope: scope} do
      other_scope = scope_fixture()
      _other_cred = credential_fixture(other_scope)
      assert Credentials.list_credentials(scope) == []
    end
  end

  describe "create_credential/2" do
    test "creates an encrypted credential", %{scope: scope} do
      attrs = valid_credential_attributes()
      assert {:ok, %Credential{} = cred} = Credentials.create_credential(scope, attrs)
      assert cred.name == attrs["name"]
      assert cred.service == "test-service"
      assert cred.encrypted_value != nil
      # The encrypted value should be the original value (decrypted via Cloak)
      assert cred.encrypted_value == attrs["value"]
    end

    test "fails with missing required fields", %{scope: scope} do
      assert {:error, changeset} = Credentials.create_credential(scope, %{})
      assert %{name: _, service: _, credential_type: _, value: _} = errors_on(changeset)
    end

    test "rejects value exceeding 10000 characters", %{scope: scope} do
      long_value = String.duplicate("x", 10_001)
      attrs = valid_credential_attributes(%{"value" => long_value})
      assert {:error, changeset} = Credentials.create_credential(scope, attrs)
      assert %{value: ["should be at most 10000 character(s)"]} = errors_on(changeset)
    end
  end

  describe "update_credential/2" do
    test "updates credential fields", %{scope: scope} do
      cred = credential_fixture(scope)
      assert {:ok, updated} = Credentials.update_credential(cred, %{"name" => "updated-name"})
      assert updated.name == "updated-name"
    end

    test "updates encrypted value when new value provided", %{scope: scope} do
      cred = credential_fixture(scope, %{"value" => "original-secret"})
      assert {:ok, updated} = Credentials.update_credential(cred, %{"value" => "new-secret"})

      {:ok, reloaded} = Credentials.get_credential(scope, updated.id)
      assert Credentials.decrypt_credential(reloaded) == "new-secret"
    end

    test "preserves encrypted value when no new value provided", %{scope: scope} do
      cred = credential_fixture(scope, %{"value" => "original-secret"})
      assert {:ok, updated} = Credentials.update_credential(cred, %{"name" => "renamed"})

      {:ok, reloaded} = Credentials.get_credential(scope, updated.id)
      assert reloaded.name == "renamed"
      assert Credentials.decrypt_credential(reloaded) == "original-secret"
    end

    test "rejects name exceeding 255 characters", %{scope: scope} do
      cred = credential_fixture(scope)
      long_name = String.duplicate("a", 256)
      assert {:error, changeset} = Credentials.update_credential(cred, %{"name" => long_name})
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "rejects service exceeding 255 characters", %{scope: scope} do
      cred = credential_fixture(scope)
      long_service = String.duplicate("s", 256)
      assert {:error, changeset} = Credentials.update_credential(cred, %{"service" => long_service})
      assert %{service: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "rejects value exceeding 10000 characters", %{scope: scope} do
      cred = credential_fixture(scope)
      long_value = String.duplicate("v", 10_001)
      assert {:error, changeset} = Credentials.update_credential(cred, %{"value" => long_value})
      assert %{value: ["should be at most 10000 character(s)"]} = errors_on(changeset)
    end
  end

  describe "delete_credential/1" do
    test "deletes a credential", %{scope: scope} do
      cred = credential_fixture(scope)
      assert {:ok, _} = Credentials.delete_credential(cred)
      assert {:error, :not_found} = Credentials.get_credential(scope, cred.id)
    end
  end

  describe "decrypt_credential/1" do
    test "returns the decrypted value", %{scope: scope} do
      attrs = valid_credential_attributes(%{"value" => "my-secret-key"})
      {:ok, cred} = Credentials.create_credential(scope, attrs)

      # Reload to get the encrypted form from DB
      {:ok, cred} = Credentials.get_credential(scope, cred.id)
      decrypted = Credentials.decrypt_credential(cred)
      assert decrypted == "my-secret-key"
    end
  end

  # ── LLM Configs ─────────────────────────────────────────────

  describe "list_llm_configs/1" do
    test "returns configs for the given user", %{scope: scope} do
      config = llm_config_fixture(scope)
      assert [listed] = Credentials.list_llm_configs(scope)
      assert listed.id == config.id
    end
  end

  describe "create_llm_config/2" do
    test "creates an encrypted LLM config", %{scope: scope} do
      attrs = valid_llm_config_attributes()
      assert {:ok, %LlmConfig{} = config} = Credentials.create_llm_config(scope, attrs)
      assert config.provider == "anthropic"
      assert config.encrypted_api_key != nil
    end

    test "fails with invalid provider", %{scope: scope} do
      attrs = valid_llm_config_attributes(%{"provider" => "invalid"})
      assert {:error, changeset} = Credentials.create_llm_config(scope, attrs)
      assert %{provider: _} = errors_on(changeset)
    end
  end

  describe "update_llm_config/2" do
    test "updates encrypted api_key when new key provided", %{scope: scope} do
      config = llm_config_fixture(scope, %{"api_key" => "sk-ant-original"})
      assert {:ok, updated} = Credentials.update_llm_config(config, %{"api_key" => "sk-ant-new"})

      {:ok, reloaded} = Credentials.get_llm_config(scope, updated.id)
      assert Credentials.decrypt_api_key(reloaded) == "sk-ant-new"
    end

    test "preserves encrypted api_key when no new key provided", %{scope: scope} do
      config = llm_config_fixture(scope, %{"api_key" => "sk-ant-original"})
      assert {:ok, updated} = Credentials.update_llm_config(config, %{"label" => "renamed"})

      {:ok, reloaded} = Credentials.get_llm_config(scope, updated.id)
      assert reloaded.label == "renamed"
      assert Credentials.decrypt_api_key(reloaded) == "sk-ant-original"
    end

    test "rejects label exceeding 255 characters", %{scope: scope} do
      config = llm_config_fixture(scope)
      long_label = String.duplicate("x", 256)
      assert {:error, changeset} = Credentials.update_llm_config(config, %{"label" => long_label})
      assert %{label: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

  end

  describe "decrypt_api_key/1" do
    test "returns the decrypted API key", %{scope: scope} do
      attrs = valid_llm_config_attributes(%{"api_key" => "sk-ant-test-12345"})
      {:ok, config} = Credentials.create_llm_config(scope, attrs)

      {:ok, config} = Credentials.get_llm_config(scope, config.id)
      decrypted = Credentials.decrypt_api_key(config)
      assert decrypted == "sk-ant-test-12345"
    end
  end
end
