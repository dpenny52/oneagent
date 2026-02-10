defmodule OneAgent.Tools.ManageCalendar do
  @moduledoc """
  Manages Google Calendar events. Requires `google_calendar` bucket
  with an OAuth credential containing a refresh_token.
  """

  @behaviour OneAgent.Tools.Tool

  @calendar_api "https://www.googleapis.com/calendar/v3"
  @token_url "https://oauth2.googleapis.com/token"

  @impl true
  def id, do: "manage_calendar"

  @impl true
  def name, do: "Manage Calendar"

  @impl true
  def description do
    "Manage Google Calendar events. Actions: 'list_events' to list upcoming events, " <>
      "'create_event' to create a new event, 'update_event' to modify an existing event, " <>
      "'delete_event' to remove an event, 'search_events' to search for events by text."
  end

  @impl true
  def bucket, do: :google_calendar

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["list_events", "create_event", "update_event", "delete_event", "search_events"],
          "description" => "The calendar action to perform"
        },
        "event_id" => %{
          "type" => "string",
          "description" => "Event ID (required for update_event and delete_event)"
        },
        "calendar_id" => %{
          "type" => "string",
          "description" => "Calendar ID (defaults to 'primary')"
        },
        "summary" => %{
          "type" => "string",
          "description" => "Event title (required for create_event)"
        },
        "description" => %{
          "type" => "string",
          "description" => "Event description"
        },
        "location" => %{
          "type" => "string",
          "description" => "Event location"
        },
        "start_time" => %{
          "type" => "string",
          "description" => "Start time in ISO 8601 format (e.g. '2025-06-15T09:00:00-05:00') or date for all-day events ('2025-06-15'). Required for create_event."
        },
        "end_time" => %{
          "type" => "string",
          "description" => "End time in ISO 8601 format or date for all-day events. Required for create_event."
        },
        "timezone" => %{
          "type" => "string",
          "description" => "IANA timezone (e.g. 'America/Chicago'). Used when start_time/end_time don't include offset."
        },
        "attendees" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of attendee email addresses"
        },
        "recurrence" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "RRULE strings (e.g. ['RRULE:FREQ=WEEKLY;COUNT=10'])"
        },
        "send_updates" => %{
          "type" => "string",
          "enum" => ["all", "externalOnly", "none"],
          "description" => "Who to send update notifications to (defaults to 'none')"
        },
        "time_min" => %{
          "type" => "string",
          "description" => "Lower bound for event start time (ISO 8601). Defaults to now for list_events."
        },
        "time_max" => %{
          "type" => "string",
          "description" => "Upper bound for event start time (ISO 8601)"
        },
        "max_results" => %{
          "type" => "integer",
          "description" => "Maximum number of events to return (default 10, max 50)"
        },
        "query" => %{
          "type" => "string",
          "description" => "Free-text search query (required for search_events)"
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
        {:error, "No Google Calendar credential configured. Connect Google Calendar in the Keys page first."}

      credential_json ->
        case Jason.decode(credential_json) do
          {:ok, %{"refresh_token" => refresh_token}} ->
            execute_with_token(input, refresh_token)

          _ ->
            {:error, "Invalid Google Calendar credential format. Please reconnect Google Calendar."}
        end
    end
  end

  defp execute_with_token(input, refresh_token) do
    case get_access_token(refresh_token) do
      {:ok, access_token} ->
        calendar_id = input["calendar_id"] || "primary"

        case input["action"] do
          "list_events" -> list_events(access_token, calendar_id, input)
          "create_event" -> create_event(access_token, calendar_id, input)
          "update_event" -> update_event(access_token, calendar_id, input)
          "delete_event" -> delete_event(access_token, calendar_id, input)
          "search_events" -> search_events(access_token, calendar_id, input)
          nil -> {:error, "Missing required parameter: action"}
          other -> {:error, "Unknown action: #{other}. Use list_events, create_event, update_event, delete_event, or search_events."}
        end

      {:error, reason} ->
        {:error, "Failed to authenticate with Google Calendar: #{reason}"}
    end
  end

  # ── Actions ──

  defp list_events(access_token, calendar_id, input) do
    max_results = min(input["max_results"] || 10, 50)
    time_min = input["time_min"] || DateTime.utc_now() |> DateTime.to_iso8601()

    params = [
      timeMin: time_min,
      maxResults: max_results,
      singleEvents: true,
      orderBy: "startTime"
    ]

    params = if input["time_max"], do: params ++ [timeMax: input["time_max"]], else: params

    case calendar_get("/calendars/#{URI.encode(calendar_id)}/events", access_token, params) do
      {:ok, body} ->
        events = format_events(body["items"] || [])
        {:ok, %{"events" => events, "count" => length(events)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_event(access_token, calendar_id, input) do
    with :ok <- require_params(input, ["summary", "start_time", "end_time"]) do
      event_body =
        %{}
        |> put_field("summary", input["summary"])
        |> put_field("description", input["description"])
        |> put_field("location", input["location"])
        |> put_time_field("start", input["start_time"], input["timezone"])
        |> put_time_field("end", input["end_time"], input["timezone"])
        |> maybe_put_attendees(input["attendees"])
        |> maybe_put_recurrence(input["recurrence"])

      send_updates = input["send_updates"] || "none"
      params = [sendUpdates: send_updates]

      case calendar_post("/calendars/#{URI.encode(calendar_id)}/events", access_token, event_body, params) do
        {:ok, body} ->
          {:ok, format_event(body)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp update_event(access_token, calendar_id, input) do
    case input["event_id"] do
      nil ->
        {:error, "Missing required parameter: event_id"}

      event_id ->
        event_body =
          %{}
          |> maybe_put_field("summary", input["summary"])
          |> maybe_put_field("description", input["description"])
          |> maybe_put_field("location", input["location"])
          |> maybe_put_time_field("start", input["start_time"], input["timezone"])
          |> maybe_put_time_field("end", input["end_time"], input["timezone"])
          |> maybe_put_attendees(input["attendees"])
          |> maybe_put_recurrence(input["recurrence"])

        send_updates = input["send_updates"] || "none"
        params = [sendUpdates: send_updates]

        case calendar_patch("/calendars/#{URI.encode(calendar_id)}/events/#{URI.encode(event_id)}", access_token, event_body, params) do
          {:ok, body} ->
            {:ok, format_event(body)}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp delete_event(access_token, calendar_id, input) do
    case input["event_id"] do
      nil ->
        {:error, "Missing required parameter: event_id"}

      event_id ->
        send_updates = input["send_updates"] || "none"
        params = [sendUpdates: send_updates]

        case calendar_delete("/calendars/#{URI.encode(calendar_id)}/events/#{URI.encode(event_id)}", access_token, params) do
          :ok ->
            {:ok, %{"deleted" => true, "event_id" => event_id}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp search_events(access_token, calendar_id, input) do
    case input["query"] do
      nil ->
        {:error, "Missing required parameter: query"}

      query ->
        max_results = min(input["max_results"] || 10, 50)
        time_min = input["time_min"] || DateTime.utc_now() |> DateTime.to_iso8601()

        params = [
          q: query,
          timeMin: time_min,
          maxResults: max_results,
          singleEvents: true,
          orderBy: "startTime"
        ]

        params = if input["time_max"], do: params ++ [timeMax: input["time_max"]], else: params

        case calendar_get("/calendars/#{URI.encode(calendar_id)}/events", access_token, params) do
          {:ok, body} ->
            events = format_events(body["items"] || [])
            {:ok, %{"events" => events, "count" => length(events), "query" => query}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ── HTTP helpers ──

  defp calendar_get(path, access_token, params) do
    url = @calendar_api <> path

    case Req.get(url, params: params, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, "Google Calendar authentication expired. Please reconnect Google Calendar."}

      {:ok, %{status: 404}} ->
        {:error, "Calendar or event not found"}

      {:ok, %{status: 410}} ->
        {:error, "Event has been deleted"}

      {:ok, %{status: status, body: body}} ->
        error_msg = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, "Google Calendar API error: #{error_msg}"}

      {:error, exception} ->
        {:error, "Google Calendar API request failed: #{Exception.message(exception)}"}
    end
  end

  defp calendar_post(path, access_token, body, params) do
    url = @calendar_api <> path

    case Req.post(url, json: body, params: params, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: status, body: resp_body}} when status in [200, 201] ->
        {:ok, resp_body}

      {:ok, %{status: 401}} ->
        {:error, "Google Calendar authentication expired. Please reconnect Google Calendar."}

      {:ok, %{status: status, body: resp_body}} ->
        error_msg = get_in(resp_body, ["error", "message"]) || "HTTP #{status}"
        {:error, "Google Calendar API error: #{error_msg}"}

      {:error, exception} ->
        {:error, "Google Calendar API request failed: #{Exception.message(exception)}"}
    end
  end

  defp calendar_patch(path, access_token, body, params) do
    url = @calendar_api <> path

    case Req.patch(url, json: body, params: params, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: resp_body}} ->
        {:ok, resp_body}

      {:ok, %{status: 401}} ->
        {:error, "Google Calendar authentication expired. Please reconnect Google Calendar."}

      {:ok, %{status: 404}} ->
        {:error, "Event not found"}

      {:ok, %{status: status, body: resp_body}} ->
        error_msg = get_in(resp_body, ["error", "message"]) || "HTTP #{status}"
        {:error, "Google Calendar API error: #{error_msg}"}

      {:error, exception} ->
        {:error, "Google Calendar API request failed: #{Exception.message(exception)}"}
    end
  end

  defp calendar_delete(path, access_token, params) do
    url = @calendar_api <> path

    case Req.request(method: :delete, url: url, params: params, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 204}} ->
        :ok

      {:ok, %{status: 401}} ->
        {:error, "Google Calendar authentication expired. Please reconnect Google Calendar."}

      {:ok, %{status: 404}} ->
        {:error, "Event not found"}

      {:ok, %{status: 410}} ->
        {:error, "Event already deleted"}

      {:ok, %{status: status, body: resp_body}} ->
        error_msg = get_in(resp_body, ["error", "message"]) || "HTTP #{status}"
        {:error, "Google Calendar API error: #{error_msg}"}

      {:error, exception} ->
        {:error, "Google Calendar API request failed: #{Exception.message(exception)}"}
    end
  end

  # ── Token refresh ──

  defp get_access_token(refresh_token) do
    client_id = Application.get_env(:oneagent, :google_calendar_client_id)
    client_secret = Application.get_env(:oneagent, :google_calendar_client_secret)

    if is_nil(client_id) || is_nil(client_secret) do
      {:error, "Google Calendar OAuth not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET."}
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

  # ── Event formatting ──

  defp format_events(items) do
    Enum.map(items, &format_event/1)
  end

  defp format_event(event) do
    %{
      "id" => event["id"],
      "summary" => event["summary"],
      "description" => event["description"],
      "location" => event["location"],
      "start" => format_event_time(event["start"]),
      "end" => format_event_time(event["end"]),
      "status" => event["status"],
      "html_link" => event["htmlLink"],
      "attendees" => format_attendees(event["attendees"]),
      "recurrence" => event["recurrence"],
      "creator" => event["creator"]
    }
  end

  defp format_event_time(nil), do: nil
  defp format_event_time(%{"dateTime" => dt}), do: dt
  defp format_event_time(%{"date" => d}), do: d
  defp format_event_time(other), do: other

  defp format_attendees(nil), do: nil

  defp format_attendees(attendees) when is_list(attendees) do
    Enum.map(attendees, fn a ->
      %{"email" => a["email"], "response_status" => a["responseStatus"]}
    end)
  end

  # ── Body building helpers ──

  defp require_params(input, keys) do
    missing = Enum.filter(keys, fn k -> is_nil(input[k]) || input[k] == "" end)

    if missing == [] do
      :ok
    else
      {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
    end
  end

  defp put_field(map, key, value) when not is_nil(value), do: Map.put(map, key, value)
  defp put_field(map, _key, nil), do: map

  defp maybe_put_field(map, key, value) when not is_nil(value), do: Map.put(map, key, value)
  defp maybe_put_field(map, _key, nil), do: map

  defp put_time_field(map, key, time, timezone) do
    Map.put(map, key, build_time_object(time, timezone))
  end

  defp maybe_put_time_field(map, _key, nil, _timezone), do: map

  defp maybe_put_time_field(map, key, time, timezone) do
    Map.put(map, key, build_time_object(time, timezone))
  end

  defp build_time_object(time, timezone) do
    if all_day_date?(time) do
      %{"date" => time}
    else
      obj = %{"dateTime" => time}
      if timezone, do: Map.put(obj, "timeZone", timezone), else: obj
    end
  end

  defp all_day_date?(time) when is_binary(time) do
    Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, time)
  end

  defp all_day_date?(_), do: false

  defp maybe_put_attendees(map, nil), do: map

  defp maybe_put_attendees(map, attendees) when is_list(attendees) do
    Map.put(map, "attendees", Enum.map(attendees, fn email -> %{"email" => email} end))
  end

  defp maybe_put_recurrence(map, nil), do: map
  defp maybe_put_recurrence(map, recurrence) when is_list(recurrence), do: Map.put(map, "recurrence", recurrence)
end
