defmodule OneAgent.Tools.CheckEmail do
  @moduledoc """
  Checks Gmail emails using the Gmail API. Requires `gmail` bucket
  with an OAuth credential containing a refresh_token.
  """

  @behaviour OneAgent.Tools.Tool

  @gmail_api "https://gmail.googleapis.com/gmail/v1/users/me"
  @token_url "https://oauth2.googleapis.com/token"
  @max_body_bytes 10_000

  @impl true
  def id, do: "check_email"

  @impl true
  def name, do: "Check Email"

  @impl true
  def description do
    "Check your Gmail inbox. Use action 'list' to list recent emails (with optional search query), or 'read' to read a specific email by message_id."
  end

  @impl true
  def bucket, do: :gmail

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["list", "read"],
          "description" => "Action to perform: 'list' to list recent emails, 'read' to read a specific email"
        },
        "query" => %{
          "type" => "string",
          "description" => "Gmail search query (e.g. 'from:someone@example.com', 'is:unread', 'subject:hello'). Only used with 'list' action."
        },
        "max_results" => %{
          "type" => "integer",
          "description" => "Maximum number of emails to return (default 10, max 20). Only used with 'list' action."
        },
        "message_id" => %{
          "type" => "string",
          "description" => "Gmail message ID to read. Required for 'read' action."
        }
      },
      "required" => ["action"]
    }
  end

  @impl true
  def required_credential_type, do: :oauth_token

  @impl true
  def execute(input, context) do
    case context[:credential_value] do
      nil ->
        {:error, "No Gmail credential configured. Connect Gmail in the Keys page first."}

      credential_json ->
        case Jason.decode(credential_json) do
          {:ok, %{"refresh_token" => refresh_token}} ->
            execute_with_token(input, refresh_token)

          _ ->
            {:error, "Invalid Gmail credential format. Please reconnect Gmail."}
        end
    end
  end

  defp execute_with_token(input, refresh_token) do
    case get_access_token(refresh_token) do
      {:ok, access_token} ->
        case input["action"] do
          "list" -> list_emails(access_token, input)
          "read" -> read_email(access_token, input)
          nil -> {:error, "Missing required parameter: action (must be 'list' or 'read')"}
          other -> {:error, "Unknown action: #{other}. Use 'list' or 'read'."}
        end

      {:error, reason} ->
        {:error, "Failed to authenticate with Gmail: #{reason}"}
    end
  end

  defp get_access_token(refresh_token) do
    client_id = Application.get_env(:oneagent, :google_gmail_client_id)
    client_secret = Application.get_env(:oneagent, :google_gmail_client_secret)

    if is_nil(client_id) || is_nil(client_secret) do
      {:error, "Gmail OAuth not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET."}
    else
      body = %{
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret
      }

      case Req.post(@token_url, form: body) do
        {:ok, %{status: 200, body: %{"access_token" => token}}} ->
          {:ok, token}

        {:ok, %{body: %{"error_description" => desc}}} ->
          {:error, desc}

        {:ok, %{status: status}} ->
          {:error, "Token refresh failed (HTTP #{status})"}

        {:error, exception} ->
          {:error, "Token refresh request failed: #{Exception.message(exception)}"}
      end
    end
  end

  defp list_emails(access_token, input) do
    max_results = min(input["max_results"] || 10, 20)

    params = [maxResults: max_results]
    params = if input["query"], do: params ++ [q: input["query"]], else: params

    case gmail_get("/messages", access_token, params) do
      {:ok, %{"messages" => messages}} when is_list(messages) ->
        email_summaries =
          messages
          |> Enum.take(max_results)
          |> Enum.map(fn %{"id" => id} -> fetch_message_metadata(access_token, id) end)
          |> Enum.reject(&is_nil/1)

        {:ok, %{
          "emails" => email_summaries,
          "count" => length(email_summaries),
          "query" => input["query"]
        }}

      {:ok, %{"resultSizeEstimate" => 0}} ->
        {:ok, %{"emails" => [], "count" => 0, "query" => input["query"]}}

      {:ok, _body} ->
        {:ok, %{"emails" => [], "count" => 0, "query" => input["query"]}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_message_metadata(access_token, message_id) do
    case gmail_get("/messages/#{message_id}", access_token, format: "metadata", metadataHeaders: "From,To,Subject,Date") do
      {:ok, msg} ->
        headers = parse_headers(msg["payload"]["headers"] || [])

        %{
          "id" => msg["id"],
          "thread_id" => msg["threadId"],
          "subject" => headers["Subject"],
          "from" => headers["From"],
          "to" => headers["To"],
          "date" => headers["Date"],
          "snippet" => msg["snippet"]
        }

      _ ->
        nil
    end
  end

  defp read_email(access_token, input) do
    case input["message_id"] do
      nil ->
        {:error, "message_id is required for the 'read' action"}

      message_id ->
        case gmail_get("/messages/#{message_id}", access_token, format: "full") do
          {:ok, msg} ->
            headers = parse_headers(msg["payload"]["headers"] || [])
            body = extract_body(msg["payload"])

            {:ok, %{
              "id" => msg["id"],
              "thread_id" => msg["threadId"],
              "subject" => headers["Subject"],
              "from" => headers["From"],
              "to" => headers["To"],
              "date" => headers["Date"],
              "snippet" => msg["snippet"],
              "body" => truncate(body, @max_body_bytes)
            }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp gmail_get(path, access_token, params) do
    url = @gmail_api <> path

    case Req.get(url, params: params, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, "Message not found"}

      {:ok, %{status: 401}} ->
        {:error, "Gmail authentication expired. Please reconnect Gmail."}

      {:ok, %{status: status, body: body}} ->
        error_msg = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, "Gmail API error: #{error_msg}"}

      {:error, exception} ->
        {:error, "Gmail API request failed: #{Exception.message(exception)}"}
    end
  end

  defp parse_headers(headers) do
    Enum.into(headers, %{}, fn %{"name" => name, "value" => value} -> {name, value} end)
  end

  @doc false
  def extract_body(%{"parts" => parts}) when is_list(parts) do
    # Prefer text/plain, fall back to text/html
    plain = Enum.find(parts, fn p -> p["mimeType"] == "text/plain" end)
    html = Enum.find(parts, fn p -> p["mimeType"] == "text/html" end)

    cond do
      plain -> decode_body_data(plain["body"]["data"])
      html -> decode_body_data(html["body"]["data"])
      true ->
        # Check nested parts (multipart/alternative inside multipart/mixed)
        nested = Enum.find_value(parts, fn p -> extract_body(p) end)
        nested || ""
    end
  end

  def extract_body(%{"body" => %{"data" => data}}) when is_binary(data) do
    decode_body_data(data)
  end

  def extract_body(_), do: ""

  defp decode_body_data(nil), do: ""

  defp decode_body_data(data) do
    # Gmail uses URL-safe base64 (RFC 4648 §5)
    case Base.url_decode64(data, padding: false) do
      {:ok, decoded} -> decoded
      :error -> ""
    end
  end

  defp truncate(text, max_bytes) when byte_size(text) > max_bytes do
    String.slice(text, 0, max_bytes) <> "\n... [truncated]"
  end

  defp truncate(text, _max_bytes), do: text
end
