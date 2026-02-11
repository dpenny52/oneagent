defmodule OneAgentWeb.TelegramChannelController do
  use OneAgentWeb, :controller

  alias OneAgent.Telegram
  alias OneAgent.Telegram.Client
  alias OneAgent.Credentials

  action_fallback OneAgentWeb.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    channels = Telegram.list_channels(scope)
    render(conn, :index, channels: channels)
  end

  def create(conn, %{"channel" => channel_params}) do
    scope = conn.assigns.current_scope

    with {:ok, bot_token} <- get_bot_token(scope, channel_params),
         {:ok, bot_id} <- Client.extract_bot_id(bot_token) do
      params = Map.put(channel_params, "bot_id", bot_id)

      case Telegram.create_channel(scope, params) do
        {:ok, channel} ->
          # Attempt to register webhook (non-blocking failure)
          webhook_url = build_webhook_url(bot_id)
          webhook_registered = register_webhook(bot_token, webhook_url, channel.secret_token)

          if webhook_registered do
            Telegram.update_channel(scope, channel, %{"webhook_registered" => true})
          end

          # Reload to get latest state
          {:ok, channel} = Telegram.get_channel(scope, channel.id)

          conn
          |> put_status(:created)
          |> render(:created, channel: channel)

        {:error, _} = error ->
          error
      end
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- Telegram.get_channel(scope, id) do
      render(conn, :show, channel: channel)
    end
  end

  def update(conn, %{"id" => id, "channel" => channel_params}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- Telegram.get_channel(scope, id),
         {:ok, channel} <- Telegram.update_channel(scope, channel, channel_params) do
      render(conn, :show, channel: channel)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, channel} <- Telegram.get_channel(scope, id) do
      # Attempt to delete webhook (best effort)
      try_delete_webhook(scope, channel)

      case Telegram.delete_channel(channel) do
        {:ok, _channel} ->
          send_resp(conn, :no_content, "")

        {:error, _} = error ->
          error
      end
    end
  end

  defp get_bot_token(scope, params) do
    credential_id = Map.get(params, "credential_id")

    case OneAgent.Credentials.get_credential(scope, credential_id) do
      {:ok, cred} ->
        {:ok, Credentials.decrypt_credential(cred)}

      {:error, :not_found} ->
        {:error, "Credential not found or not owned by you"}
    end
  end

  defp build_webhook_url(bot_id) do
    base_url = Application.get_env(:oneagent, :webhook_base_url, OneAgentWeb.Endpoint.url())
    "#{base_url}/api/webhooks/telegram/#{bot_id}"
  end

  defp register_webhook(bot_token, url, secret_token) do
    case Client.set_webhook(bot_token, url, secret_token) do
      :ok -> true
      {:error, _} -> false
    end
  end

  defp try_delete_webhook(scope, channel) do
    case OneAgent.Credentials.get_credential(scope, channel.credential_id) do
      {:ok, cred} ->
        bot_token = Credentials.decrypt_credential(cred)
        Client.delete_webhook(bot_token)

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end
end
