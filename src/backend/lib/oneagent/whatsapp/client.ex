defmodule OneAgent.WhatsApp.Client do
  @moduledoc """
  WhatsApp Cloud API client. Handles signature verification,
  message parsing, and sending replies.
  """

  require Logger

  @graph_api_base "https://graph.facebook.com/v21.0"
  @max_message_length 4096

  # ── Signature Verification ─────────────────────────────────

  @doc """
  Verifies the HMAC-SHA256 signature from Meta's X-Hub-Signature-256 header.
  Returns `:ok` or `:error`.
  """
  def verify_signature(raw_body, signature_header, app_secret) do
    case signature_header do
      "sha256=" <> received_hash ->
        expected_hash =
          :crypto.mac(:hmac, :sha256, app_secret, raw_body)
          |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(expected_hash, received_hash) do
          :ok
        else
          :error
        end

      _ ->
        :error
    end
  end

  # ── Message Parsing ────────────────────────────────────────

  @doc """
  Extracts text messages from Meta's webhook payload.
  Returns a list of `%{from: phone, text: body, phone_number_id: id, message_id: id}`.
  Ignores non-text messages (images, status updates, etc).
  """
  def parse_messages(payload) do
    case payload do
      %{"entry" => entries} ->
        entries
        |> Enum.flat_map(fn entry ->
          entry
          |> Map.get("changes", [])
          |> Enum.flat_map(&extract_messages/1)
        end)

      _ ->
        []
    end
  end

  defp extract_messages(%{"value" => value}) do
    phone_number_id = get_in(value, ["metadata", "phone_number_id"])
    messages = Map.get(value, "messages", [])

    messages
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map(fn msg ->
      %{
        from: msg["from"],
        text: get_in(msg, ["text", "body"]),
        phone_number_id: phone_number_id,
        message_id: msg["id"]
      }
    end)
  end

  defp extract_messages(_), do: []

  # ── Sending Messages ───────────────────────────────────────

  @doc """
  Sends a text message to a WhatsApp user via the Cloud API.
  Truncates message to 4096 chars (WhatsApp limit).
  """
  def send_text_message(phone_number_id, to, text, access_token) do
    text = truncate(text, @max_message_length)
    url = "#{graph_api_base()}/#{phone_number_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      to: to,
      type: "text",
      text: %{body: text}
    }

    case Req.post(url,
           json: body,
           headers: [{"authorization", "Bearer #{access_token}"}]
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("WhatsApp API error: status=#{status} body=#{inspect(resp_body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("WhatsApp API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Marks a message as read (blue checkmarks).
  """
  def mark_as_read(phone_number_id, message_id, access_token) do
    url = "#{graph_api_base()}/#{phone_number_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      status: "read",
      message_id: message_id
    }

    case Req.post(url,
           json: body,
           headers: [{"authorization", "Bearer #{access_token}"}]
         ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      _ -> :error
    end
  end

  # ── Helpers ────────────────────────────────────────────────

  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max - 3) <> "..."

  defp graph_api_base do
    Application.get_env(:oneagent, :whatsapp_graph_api_base, @graph_api_base)
  end
end
