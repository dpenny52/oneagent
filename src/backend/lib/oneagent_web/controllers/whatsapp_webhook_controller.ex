defmodule OneAgentWeb.WhatsAppWebhookController do
  use OneAgentWeb, :controller

  alias OneAgent.WhatsApp
  alias OneAgent.WhatsApp.Client
  alias OneAgent.Accounts.Scope
  alias OneAgent.Credentials

  require Logger

  @doc """
  GET /api/webhooks/whatsapp — Meta webhook verification handshake.
  Meta sends hub.mode, hub.verify_token, and hub.challenge as query params.
  """
  # Meta challenges are numeric strings; allow alphanumeric, hyphens, underscores, max 256 chars
  @challenge_pattern ~r/\A[a-zA-Z0-9_\-]{1,256}\z/

  def verify(conn, params) do
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    with "subscribe" <- mode,
         true <- is_binary(token) and token != "",
         true <- is_binary(challenge) and Regex.match?(@challenge_pattern, challenge),
         %{} <- WhatsApp.get_channel_by_verify_token(token) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: "Verification failed"}))
    end
  end

  @doc """
  POST /api/webhooks/whatsapp — Incoming messages from Meta.
  Verifies HMAC signature before processing. Returns 200 on success, 403 on invalid signature.
  """
  def handle(conn, _params) do
    payload = conn.body_params
    raw_body = conn.assigns[:raw_body] || ""
    signature = get_req_header(conn, "x-hub-signature-256") |> List.first()

    messages = Client.parse_messages(payload)

    case messages do
      [] ->
        # Status-only or empty payload — no messages to process. Return 200 to satisfy Meta.
        send_resp(conn, 200, "ok")

      [first_message | _] ->
        # Verify HMAC signature before spawning any tasks
        case verify_webhook_signature(first_message.phone_number_id, raw_body, signature) do
          {:ok, channel, access_token} ->
            for message <- messages do
              Task.Supervisor.start_child(
                OneAgent.WhatsApp.TaskSupervisor,
                fn -> process_message(message, channel, access_token) end
              )
            end

            send_resp(conn, 200, "ok")

          {:error, reason} ->
            Logger.warning("WhatsApp webhook rejected: #{reason}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(403, Jason.encode!(%{error: "Invalid signature"}))
        end
    end
  end

  defp verify_webhook_signature(phone_number_id, raw_body, signature) do
    with channel when not is_nil(channel) <-
           WhatsApp.get_active_channel_by_phone_number_id(phone_number_id),
         {:ok, cred_value} <- decrypt_credential(channel.credential),
         {:ok, %{"access_token" => access_token, "app_secret" => app_secret}} <-
           parse_credential(cred_value),
         :ok <- Client.verify_signature(raw_body, signature || "", app_secret) do
      {:ok, channel, access_token}
    else
      nil -> {:error, "no active channel for phone_number_id=#{phone_number_id}"}
      {:error, :invalid_credential} -> {:error, "invalid credential for phone_number_id=#{phone_number_id}"}
      :error -> {:error, "HMAC signature verification failed for phone_number_id=#{phone_number_id}"}
      {:error, reason} -> {:error, "#{inspect(reason)}"}
    end
  end

  defp process_message(message, channel, access_token) do
    %{from: from, text: text, phone_number_id: phone_number_id, message_id: message_id} = message

    # Mark as read (best effort)
    Client.mark_as_read(phone_number_id, message_id, access_token)

    # Build scope from channel owner and invoke agent
    scope = Scope.for_user(channel.user)

    case invoke_agent(scope, channel.agent, text) do
      {:ok, response} ->
        Client.send_text_message(phone_number_id, from, response, access_token)

      {:error, reason} ->
        Logger.error("Agent invocation failed: #{inspect(reason)}")
        Client.send_text_message(phone_number_id, from, "Sorry, I couldn't process your message right now. Please try again later.", access_token)
    end
  rescue
    e ->
      Logger.error("Unexpected error processing WhatsApp message: #{Exception.message(e)}")
  end

  defp decrypt_credential(credential) do
    value = Credentials.decrypt_credential(credential)
    {:ok, value}
  end

  defp parse_credential(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, %{"access_token" => _, "app_secret" => _} = parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_credential}
    end
  end

  defp parse_credential(%{"access_token" => _, "app_secret" => _} = value), do: {:ok, value}
  defp parse_credential(_), do: {:error, :invalid_credential}

  defp invoke_agent(scope, agent, text) do
    case OneAgent.Runtime.invoke_agent(scope, agent.id, text, "webhook", %{channel: "whatsapp"}) do
      {:ok, %{response: response}} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
