defmodule OneAgentWeb.CredentialJSON do
  alias OneAgent.Credentials.{Credential, LlmConfig}

  def render("index.json", %{credentials: credentials}) do
    %{data: Enum.map(credentials, &credential_data/1)}
  end

  def render("show.json", %{credential: credential}) do
    %{data: credential_data(credential)}
  end

  def render("llm_configs.json", %{llm_configs: configs}) do
    %{data: Enum.map(configs, &llm_config_data/1)}
  end

  def render("llm_config.json", %{llm_config: config}) do
    %{data: llm_config_data(config)}
  end

  defp credential_data(%Credential{} = cred) do
    %{
      id: cred.id,
      name: cred.name,
      service: cred.service,
      credential_type: cred.credential_type,
      metadata: cred.metadata,
      expires_at: cred.expires_at,
      last_used_at: cred.last_used_at,
      inserted_at: cred.inserted_at,
      updated_at: cred.updated_at
      # NOTE: encrypted_value is never exposed
    }
  end

  defp llm_config_data(%LlmConfig{} = config) do
    %{
      id: config.id,
      provider: config.provider,
      label: config.label,
      is_default: config.is_default,
      inserted_at: config.inserted_at,
      updated_at: config.updated_at
      # NOTE: encrypted_api_key is never exposed
    }
  end
end
