defmodule OneAgentWeb.TelegramWebhookController do
  use OneAgentWeb, :controller

  alias OneAgent.Telegram
  alias OneAgent.Telegram.Client
  alias OneAgent.Accounts.Scope
  alias OneAgent.Credentials

  require Logger

  @doc """
  POST /api/webhooks/telegram/:bot_id — Incoming messages from Telegram.
  Verifies X-Telegram-Bot-Api-Secret-Token header before processing.
  """
  def handle(conn, %{"bot_id" => bot_id}) do
    payload = conn.body_params
    secret_header = get_req_header(conn, "x-telegram-bot-api-secret-token") |> List.first()

    case Telegram.get_channel_by_bot_id(bot_id) do
      nil ->
        Logger.warning("Telegram webhook: no channel for bot_id=#{bot_id}")
        send_resp(conn, 200, "ok")

      channel ->
        case Client.verify_secret_token(secret_header, channel.secret_token) do
          :ok ->
            process_update(payload, channel)
            send_resp(conn, 200, "ok")

          :error ->
            Logger.warning("Telegram webhook: invalid secret token for bot_id=#{bot_id}")
            send_resp(conn, 200, "ok")
        end
    end
  end

  defp process_update(payload, channel) do
    case Client.parse_message(payload) do
      {:ok, message} ->
        Task.Supervisor.start_child(
          OneAgent.Telegram.TaskSupervisor,
          fn -> process_message(message, channel) end
        )

      :ignore ->
        :ok
    end
  end

  defp process_message(message, channel) do
    %{chat_id: chat_id, text: text} = message

    # Auto-capture owner_chat_id on first message
    chat_id_str = to_string(chat_id)
    channel = auto_capture_owner(channel, chat_id_str)

    # Trusted if sender matches owner
    trusted = chat_id_str == channel.owner_chat_id

    # Decrypt bot token from credential
    bot_token = Credentials.decrypt_credential(channel.credential)

    # Build scope from channel owner and invoke agent
    scope = Scope.for_user(channel.user)

    case invoke_agent(scope, channel.agent, text, %{trusted_sender: trusted}) do
      {:ok, response} ->
        Client.send_message(bot_token, chat_id, response)

      {:error, reason} ->
        Logger.error("Agent invocation failed: #{inspect(reason)}")

        Client.send_message(
          bot_token,
          chat_id,
          "Sorry, I couldn't process your message right now. Please try again later."
        )
    end
  rescue
    e ->
      Logger.error("Unexpected error processing Telegram message: #{Exception.message(e)}")
  end

  defp auto_capture_owner(%{owner_chat_id: nil} = channel, chat_id_str) do
    case Telegram.update_channel_unscoped(channel, %{owner_chat_id: chat_id_str}) do
      {:ok, updated} -> updated
      {:error, _} -> channel
    end
  end

  defp auto_capture_owner(channel, _chat_id_str), do: channel

  defp invoke_agent(scope, agent, text, opts) do
    case OneAgent.Runtime.invoke_agent(scope, agent.id, text, "webhook", opts) do
      {:ok, %{response: response}} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
