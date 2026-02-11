defmodule OneAgent.Telegram.Client do
  @moduledoc """
  Telegram Bot API client. Handles message sending, webhook management,
  secret token verification, and message parsing.
  """

  require Logger

  @bot_api_base "https://api.telegram.org"
  @max_message_length 4096

  # ── Secret Token Verification ────────────────────────────

  @doc """
  Verifies the X-Telegram-Bot-Api-Secret-Token header value.
  Uses constant-time comparison to prevent timing attacks.
  """
  def verify_secret_token(header_value, expected) do
    if is_binary(header_value) and is_binary(expected) and
         Plug.Crypto.secure_compare(header_value, expected) do
      :ok
    else
      :error
    end
  end

  # ── Message Parsing ──────────────────────────────────────

  @doc """
  Extracts chat_id, text, and from info from a Telegram webhook payload.
  Returns {:ok, %{chat_id: id, text: text, from: from, message_id: id}} or :ignore.
  """
  def parse_message(%{"message" => %{"text" => text, "chat" => %{"id" => chat_id}} = msg}) do
    {:ok,
     %{
       chat_id: chat_id,
       text: text,
       from: msg["from"],
       message_id: msg["message_id"]
     }}
  end

  def parse_message(_payload), do: :ignore

  # ── Sending Messages ─────────────────────────────────────

  @doc """
  Sends a text message to a Telegram chat via the Bot API.
  Truncates message to 4096 chars (Telegram limit).
  """
  def send_message(bot_token, chat_id, text) do
    text = truncate(text, @max_message_length)
    url = "#{bot_api_base()}/bot#{bot_token}/sendMessage"

    body = %{
      chat_id: chat_id,
      text: text,
      parse_mode: "Markdown"
    }

    case Req.post(url, json: body) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("Telegram API error: status=#{status} body=#{inspect(resp_body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Telegram API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  # ── Webhook Management ───────────────────────────────────

  @doc """
  Registers a webhook URL with Telegram's setWebhook API.
  """
  def set_webhook(bot_token, url, secret_token) do
    api_url = "#{bot_api_base()}/bot#{bot_token}/setWebhook"

    body = %{
      url: url,
      secret_token: secret_token,
      allowed_updates: ["message"]
    }

    case Req.post(api_url, json: body) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("Telegram setWebhook error: status=#{status} body=#{inspect(resp_body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Telegram setWebhook request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Removes the webhook via Telegram's deleteWebhook API.
  """
  def delete_webhook(bot_token) do
    url = "#{bot_api_base()}/bot#{bot_token}/deleteWebhook"

    case Req.post(url, json: %{}) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error(
          "Telegram deleteWebhook error: status=#{status} body=#{inspect(resp_body)}"
        )

        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Telegram deleteWebhook request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  # ── Helpers ──────────────────────────────────────────────

  @doc """
  Extracts the numeric bot_id prefix from a bot token.
  E.g., "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" -> "123456"
  """
  def extract_bot_id(bot_token) when is_binary(bot_token) do
    case String.split(bot_token, ":", parts: 2) do
      [bot_id, _rest] when bot_id != "" -> {:ok, bot_id}
      _ -> {:error, :invalid_token_format}
    end
  end

  def extract_bot_id(_), do: {:error, :invalid_token_format}

  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max - 3) <> "..."

  defp bot_api_base do
    Application.get_env(:oneagent, :telegram_bot_api_base, @bot_api_base)
  end
end
