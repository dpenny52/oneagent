defmodule OneAgent.CredentialsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `OneAgent.Credentials` context.
  """

  alias OneAgent.Credentials
  alias OneAgent.AccountsFixtures

  def valid_credential_attributes(attrs \\ %{}) do
    Map.merge(%{
      "name" => "test-cred-#{System.unique_integer([:positive])}",
      "service" => "test-service",
      "credential_type" => "api_key",
      "value" => "sk-test-#{System.unique_integer([:positive])}"
    }, attrs)
  end

  def credential_fixture(scope, attrs \\ %{}) do
    {:ok, credential} =
      attrs
      |> valid_credential_attributes()
      |> then(&Credentials.create_credential(scope, &1))

    credential
  end

  def valid_llm_config_attributes(attrs \\ %{}) do
    Map.merge(%{
      "provider" => "anthropic",
      "api_key" => "sk-ant-test-#{System.unique_integer([:positive])}",
      "label" => "test-config-#{System.unique_integer([:positive])}"
    }, attrs)
  end

  def llm_config_fixture(scope, attrs \\ %{}) do
    {:ok, config} =
      attrs
      |> valid_llm_config_attributes()
      |> then(&Credentials.create_llm_config(scope, &1))

    config
  end

  def scope_fixture do
    user = AccountsFixtures.confirmed_user_fixture()
    OneAgent.Accounts.Scope.for_user(user)
  end
end
