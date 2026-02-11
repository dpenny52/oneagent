defmodule OneAgent.Tools.SendTelegram do
  @moduledoc """
  Sends a Telegram message to a chat. Requires `telegram` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.Telegram
  alias OneAgent.Telegram.Client

  @max_message_length 4096

  @impl true
  def id, do: "send_telegram"

  @impl true
  def name, do: "Send Telegram"

  @impl true
  def description do
    "Send a Telegram message to a chat. The chat_id can be a user ID or group ID. Requires telegram permission."
  end

  @impl true
  def bucket, do: :telegram

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "chat_id" => %{
          "type" => "string",
          "description" =>
            "Telegram chat ID (user or group). Can be a numeric string."
        },
        "message" => %{
          "type" => "string",
          "description" => "Message text to send (max 4096 characters)"
        }
      },
      "required" => ["chat_id", "message"]
    }
  end

  @impl true
  def required_credential_type, do: :api_key

  @impl true
  def execute(input, context) do
    chat_id = input["chat_id"]
    message = input["message"]

    cond do
      !is_binary(chat_id) or String.trim(chat_id) == "" ->
        {:error, "Missing required parameter: chat_id"}

      !is_binary(message) or String.trim(message) == "" ->
        {:error, "Missing required parameter: message"}

      String.length(message) > @max_message_length ->
        {:error, "Message too long (max #{@max_message_length} characters)"}

      true ->
        do_send(chat_id, message, context)
    end
  end

  defp do_send(chat_id, message, context) do
    case context[:credential_value] do
      nil ->
        {:error,
         "No Telegram credential configured. Add a Telegram bot token in the Keys page."}

      bot_token ->
        agent = context[:agent]

        case Telegram.get_channel_by_agent(agent.id) do
          nil ->
            {:error,
             "No active Telegram channel configured for this agent. Set up a Telegram channel first."}

          _channel ->
            case Client.send_message(bot_token, chat_id, message) do
              :ok ->
                {:ok,
                 %{
                   "sent_to" => chat_id,
                   "message_preview" => String.slice(message, 0, 100)
                 }}

              {:error, :api_error} ->
                {:error, "Telegram API error. Check your bot token."}

              {:error, :request_failed} ->
                {:error, "Failed to connect to Telegram API. Please try again."}
            end
        end
    end
  end
end
