defmodule OneAgentWeb.LlmConfigJSON do
  alias OneAgent.Credentials.LlmConfig

  def render("index.json", %{configs: configs}) do
    %{data: Enum.map(configs, &llm_config_data/1)}
  end

  def render("show.json", %{llm_config: config}) do
    %{data: llm_config_data(config)}
  end

  defp llm_config_data(%LlmConfig{} = config) do
    %{
      id: config.id,
      provider: config.provider,
      label: config.label,
      is_default: config.is_default,
      inserted_at: config.inserted_at,
      updated_at: config.updated_at
    }
  end
end
