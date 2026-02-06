defmodule OneAgentWeb.WhatsAppChannelController do
  use OneAgentWeb, :controller

  alias OneAgent.WhatsApp

  action_fallback OneAgentWeb.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    channels = WhatsApp.list_channels(scope)
    render(conn, :index, channels: channels)
  end

  def create(conn, %{"channel" => channel_params}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- WhatsApp.create_channel(scope, channel_params) do
      conn
      |> put_status(:created)
      |> render(:created, channel: channel)
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- WhatsApp.get_channel(scope, id) do
      render(conn, :show, channel: channel)
    end
  end

  def update(conn, %{"id" => id, "channel" => channel_params}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- WhatsApp.get_channel(scope, id),
         {:ok, channel} <- WhatsApp.update_channel(scope, channel, channel_params) do
      render(conn, :show, channel: channel)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- WhatsApp.get_channel(scope, id),
         {:ok, _channel} <- WhatsApp.delete_channel(channel) do
      send_resp(conn, :no_content, "")
    end
  end
end
