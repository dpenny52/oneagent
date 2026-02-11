defmodule OneAgentWeb.TelegramChannelJSON do
  alias OneAgent.Telegram.Channel

  def render("index.json", %{channels: channels}) do
    %{data: Enum.map(channels, &channel_data/1)}
  end

  def render("show.json", %{channel: channel}) do
    %{data: channel_data(channel)}
  end

  def render("created.json", %{channel: channel}) do
    %{data: channel_data_with_secret(channel)}
  end

  defp channel_data(%Channel{} = channel) do
    %{
      id: channel.id,
      agent_id: channel.agent_id,
      credential_id: channel.credential_id,
      bot_id: channel.bot_id,
      bot_username: channel.bot_username,
      active: channel.active,
      webhook_registered: channel.webhook_registered,
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp channel_data_with_secret(%Channel{} = channel) do
    channel
    |> channel_data()
    |> Map.put(:secret_token, channel.secret_token)
  end
end
