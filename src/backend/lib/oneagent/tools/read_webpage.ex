defmodule OneAgent.Tools.ReadWebpage do
  @moduledoc """
  Fetches a URL and extracts text content. Requires `web_access` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "read_webpage"

  @impl true
  def name, do: "Read Webpage"

  @impl true
  def description do
    "Fetch a URL and extract its text content. Useful for reading articles, documentation, or any web page."
  end

  @impl true
  def bucket, do: :web_access

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "url" => %{
          "type" => "string",
          "description" => "The URL to fetch and read"
        }
      },
      "required" => ["url"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, _context) do
    url = input["url"]

    with :ok <- OneAgent.Tools.UrlValidator.validate(url),
         {:ok, resp} <- Req.get(url, headers: [{"user-agent", "OneAgent/1.0"}]) do
      handle_response(url, resp)
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to fetch URL: #{inspect(reason)}"}
    end
  end

  defp handle_response(url, %Req.Response{status: status, body: body}) when status in 200..299 do
    text = extract_text(body)
    {:ok, %{"url" => url, "text" => truncate(text, 30_000), "status" => status}}
  end

  defp handle_response(_url, %Req.Response{status: status}) do
    {:error, "Failed to fetch URL: HTTP #{status}"}
  end

  defp extract_text(body) when is_binary(body) do
    body
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_text(body) when is_map(body) do
    Jason.encode!(body)
  end

  defp extract_text(body), do: inspect(body)

  defp truncate(text, max) do
    if String.length(text) > max do
      String.slice(text, 0, max) <> "\n... [truncated]"
    else
      text
    end
  end
end
