defmodule OneAgent.Tools.SendWhatsApp do
  @moduledoc """
  Sends a WhatsApp message to a phone number. Requires `whatsapp` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.WhatsApp
  alias OneAgent.WhatsApp.Client

  @phone_regex ~r/^\d{7,15}$/
  @max_message_length 4096

  @impl true
  def id, do: "send_whatsapp"

  @impl true
  def name, do: "Send WhatsApp"

  @impl true
  def description do
    "Send a WhatsApp message to a phone number. The phone number must be in international format (digits only, no + prefix). Requires whatsapp permission."
  end

  @impl true
  def bucket, do: :whatsapp

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "to" => %{
          "type" => "string",
          "description" => "Recipient phone number in international format (digits only, 7-15 digits, no + prefix). Example: 15551234567"
        },
        "message" => %{
          "type" => "string",
          "description" => "Message text to send (max 4096 characters)"
        }
      },
      "required" => ["to", "message"]
    }
  end

  @impl true
  def required_credential_type, do: :custom

  @impl true
  def execute(input, context) do
    to = input["to"]
    message = input["message"]

    cond do
      !is_binary(to) or to == "" ->
        {:error, "Missing required parameter: to (recipient phone number)"}

      not Regex.match?(@phone_regex, to) ->
        {:error, "Invalid phone number: must be 7-15 digits only (no + prefix, spaces, or dashes)"}

      !is_binary(message) or String.trim(message) == "" ->
        {:error, "Missing required parameter: message (message text)"}

      String.length(message) > @max_message_length ->
        {:error, "Message too long (max #{@max_message_length} characters)"}

      true ->
        do_send(to, message, context)
    end
  end

  defp do_send(to, message, context) do
    case context[:credential_value] do
      nil ->
        {:error, "No WhatsApp credential configured. Add a WhatsApp credential with access_token in the Keys page."}

      credential_json ->
        with {:ok, access_token} <- parse_access_token(credential_json),
             {:ok, phone_number_id} <- get_phone_number_id(context) do
          case Client.send_text_message(phone_number_id, to, message, access_token) do
            :ok ->
              {:ok, %{
                "sent_to" => to,
                "message_preview" => String.slice(message, 0, 100)
              }}

            {:error, :api_error} ->
              {:error, "WhatsApp API error. Check your access token and phone number."}

            {:error, :request_failed} ->
              {:error, "Failed to connect to WhatsApp API. Please try again."}
          end
        end
    end
  end

  defp parse_access_token(credential_json) do
    case Jason.decode(credential_json) do
      {:ok, %{"access_token" => token}} when is_binary(token) and token != "" ->
        {:ok, token}

      {:ok, _} ->
        {:error, "WhatsApp credential missing access_token. Update your credential in the Keys page."}

      {:error, _} ->
        {:error, "Invalid WhatsApp credential format. Update your credential in the Keys page."}
    end
  end

  defp get_phone_number_id(context) do
    agent = context[:agent]

    case WhatsApp.get_active_channel_by_agent_id(agent.id) do
      nil ->
        {:error, "No active WhatsApp channel configured for this agent. Set up a WhatsApp channel first."}

      channel ->
        {:ok, channel.phone_number_id}
    end
  end
end
