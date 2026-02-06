defmodule OneAgent.Credentials do
  @moduledoc """
  The Credentials context. Manages encrypted storage of external
  service credentials and LLM API configurations.

  All queries are scoped to the authenticated user via scope.
  """

  import Ecto.Query
  alias OneAgent.Repo
  alias OneAgent.Credentials.{Credential, LlmConfig}

  # ── Credentials CRUD ─────────────────────────────────────────

  def list_credentials(%{user: user}) do
    Credential
    |> where(user_id: ^user.id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_credential(%{user: user}, id) do
    case Repo.get_by(Credential, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      credential -> {:ok, credential}
    end
  end

  def create_credential(%{user: user}, attrs) do
    %Credential{user_id: user.id}
    |> Credential.changeset(attrs)
    |> Repo.insert()
  end

  def update_credential(%Credential{} = credential, attrs) do
    credential
    |> Credential.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_credential(%Credential{} = credential) do
    Repo.delete(credential)
  end

  @doc """
  Decrypts and returns the credential value. Also touches last_used_at.
  This should only be called from the ToolExecutor at execution time.
  """
  def decrypt_credential(%Credential{} = credential) do
    credential
    |> Credential.touch_last_used()
    |> Repo.update()

    credential.encrypted_value
  end

  # ── LLM Configs CRUD ────────────────────────────────────────

  def list_llm_configs(%{user: user}) do
    LlmConfig
    |> where(user_id: ^user.id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_llm_config(%{user: user}, id) do
    case Repo.get_by(LlmConfig, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  def get_default_llm_config(%{user: user}, provider) do
    LlmConfig
    |> where(user_id: ^user.id, provider: ^provider, is_default: true)
    |> Repo.one()
  end

  def create_llm_config(%{user: user}, attrs) do
    %LlmConfig{user_id: user.id}
    |> LlmConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_llm_config(%LlmConfig{} = config, attrs) do
    config
    |> LlmConfig.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_llm_config(%LlmConfig{} = config) do
    Repo.delete(config)
  end

  @doc """
  Decrypts and returns the API key. Should only be called by the LLM client layer.
  """
  def decrypt_api_key(%LlmConfig{} = config) do
    config.encrypted_api_key
  end
end
