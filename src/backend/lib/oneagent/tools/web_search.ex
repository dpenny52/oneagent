defmodule OneAgent.Tools.WebSearch do
  @moduledoc """
  Searches the web using the Tavily API. Requires `web_search` bucket
  with an API key credential.
  """

  @behaviour OneAgent.Tools.Tool

  @tavily_url "https://api.tavily.com/search"
  @max_query_length 2000
  @max_content_chars 3000
  @request_timeout 30_000

  @impl true
  def id, do: "web_search"

  @impl true
  def name, do: "Web Search"

  @impl true
  def description do
    "Search the web for current information. Returns titles, URLs, and content snippets from relevant web pages."
  end

  @impl true
  def bucket, do: :web_search

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "query" => %{
          "type" => "string",
          "description" => "The search query (max 2000 characters)"
        },
        "max_results" => %{
          "type" => "integer",
          "description" => "Maximum number of results to return (default 5, max 10)"
        },
        "search_depth" => %{
          "type" => "string",
          "enum" => ["basic", "advanced"],
          "description" => "Search depth: 'basic' for quick results, 'advanced' for more thorough search (default: basic)"
        },
        "include_domains" => %{
          "type" => "string",
          "description" => "Comma-separated list of domains to restrict search to (e.g. 'reddit.com,stackoverflow.com')"
        },
        "exclude_domains" => %{
          "type" => "string",
          "description" => "Comma-separated list of domains to exclude from results"
        }
      },
      "required" => ["query"]
    }
  end

  @impl true
  def required_credential_type, do: :api_key

  @impl true
  def execute(input, context) do
    case context[:credential_value] do
      nil ->
        {:error, "No Tavily API key configured. Add a web_search credential with your Tavily API key."}

      api_key ->
        execute_search(input, String.trim(api_key))
    end
  end

  defp execute_search(input, api_key) do
    query = (input["query"] || "") |> String.trim()

    cond do
      query == "" ->
        {:error, "Missing required parameter: query"}

      String.length(query) > @max_query_length ->
        {:error, "Query too long (#{String.length(query)} chars, max #{@max_query_length})"}

      true ->
        do_search(query, input, api_key)
    end
  end

  defp do_search(query, input, api_key) do
    max_results = min(input["max_results"] || 5, 10)
    search_depth = if input["search_depth"] in ["basic", "advanced"], do: input["search_depth"], else: "basic"

    body = %{
      api_key: api_key,
      query: query,
      max_results: max_results,
      search_depth: search_depth,
      include_answer: false
    }

    body = maybe_add_domains(body, :include_domains, input["include_domains"])
    body = maybe_add_domains(body, :exclude_domains, input["exclude_domains"])

    case Req.post(@tavily_url, json: body, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: response}} ->
        format_results(response, query)

      {:ok, %{status: 401}} ->
        {:error, "Invalid Tavily API key. Please check your web_search credential."}

      {:ok, %{status: 429}} ->
        {:error, "Tavily rate limit exceeded. Please try again later."}

      {:ok, %{status: status, body: body}} ->
        error_msg = if is_map(body), do: body["message"] || body["detail"] || "HTTP #{status}", else: "HTTP #{status}"
        {:error, "Web search failed: #{error_msg}"}

      {:error, exception} ->
        {:error, "Web search request failed: #{Exception.message(exception)}"}
    end
  end

  defp maybe_add_domains(body, _key, nil), do: body
  defp maybe_add_domains(body, _key, ""), do: body
  defp maybe_add_domains(body, key, domains_str) do
    domains =
      domains_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if domains == [], do: body, else: Map.put(body, key, domains)
  end

  defp format_results(response, query) do
    results =
      (response["results"] || [])
      |> Enum.map(fn r ->
        %{
          "title" => r["title"],
          "url" => r["url"],
          "content" => OneAgent.TextUtils.truncate_chars(r["content"] || "", @max_content_chars),
          "score" => r["score"]
        }
      end)

    {:ok, %{
      "results" => results,
      "count" => length(results),
      "query" => query
    }}
  end
end
