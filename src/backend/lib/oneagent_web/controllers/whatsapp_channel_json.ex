defmodule OneAgentWeb.WhatsAppChannelJSON do
  alias OneAgent.WhatsApp.Channel

  def render("index.json", %{channels: channels}) do
    %{data: Enum.map(channels, &channel_data/1)}
  end

  def render("show.json", %{channel: channel}) do
    %{data: channel_data(channel)}
  end

  def render("created.json", %{channel: channel}) do
    %{data: channel_data_with_verify_token(channel)}
  end

  defp channel_data(%Channel{} = channel) do
    %{
      id: channel.id,
      agent_id: channel.agent_id,
      credential_id: channel.credential_id,
      phone_number_id: channel.phone_number_id,
      display_phone_number: channel.display_phone_number,
      active: channel.active,
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp channel_data_with_verify_token(%Channel{} = channel) do
    channel
    |> channel_data()
    |> Map.put(:verify_token, channel.verify_token)
  end
end
