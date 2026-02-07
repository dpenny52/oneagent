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
  def verify(conn, params) do
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    with "subscribe" <- mode,
         true <- is_binary(token) and token != "",
         %{} <- WhatsApp.get_channel_by_verify_token(token) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge || "")
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: "Verification failed"}))
    end
  end

  @doc """
  POST /api/webhooks/whatsapp — Incoming messages from Meta.
  Returns 200 immediately, processes messages asynchronously.
  """
  def handle(conn, _params) do
    payload = conn.body_params
    raw_body = conn.assigns[:raw_body] || ""
    signature = get_req_header(conn, "x-hub-signature-256") |> List.first()

    messages = Client.parse_messages(payload)

    for message <- messages do
      Task.Supervisor.start_child(
        OneAgent.WhatsApp.TaskSupervisor,
        fn -> process_message(message, raw_body, signature) end
      )
    end

    send_resp(conn, 200, "ok")
  end

  defp process_message(message, raw_body, signature) do
    %{from: from, text: text, phone_number_id: phone_number_id, message_id: message_id} = message

    with channel when not is_nil(channel) <-
           WhatsApp.get_active_channel_by_phone_number_id(phone_number_id),
         {:ok, cred_value} <- decrypt_credential(channel.credential),
         {:ok, %{"access_token" => access_token, "app_secret" => app_secret}} <-
           parse_credential(cred_value),
         :ok <- Client.verify_signature(raw_body, signature || "", app_secret) do
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
    else
      nil ->
        Logger.warning("No active channel for phone_number_id=#{phone_number_id}")

      {:error, :invalid_credential} ->
        Logger.error("Invalid credential format for phone_number_id=#{phone_number_id}")

      :error ->
        Logger.warning("HMAC signature verification failed for phone_number_id=#{phone_number_id}")

      {:error, reason} ->
        Logger.error("WhatsApp message processing error: #{inspect(reason)}")
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
    case OneAgent.Runtime.invoke_agent(scope, agent.id, text, "webhook") do
      {:ok, %{response: response}} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
