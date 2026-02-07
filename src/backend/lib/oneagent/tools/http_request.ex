defmodule OneAgent.Tools.HttpRequest do
  @moduledoc """
  Makes HTTP requests. GET requires `web_access` bucket,
  POST/PUT/DELETE require `data_write` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  @valid_methods ~w(get head post put patch delete)
  @request_timeout 30_000

  @impl true
  def id, do: "http_request"

  @impl true
  def name, do: "HTTP Request"

  @impl true
  def description do
    "Make an HTTP request to a URL. GET requests read data, POST/PUT/DELETE modify data."
  end

  @impl true
  def bucket, do: nil # Dynamic — resolved by bucket_for_input/1

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "method" => %{
          "type" => "string",
          "enum" => ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"],
          "description" => "HTTP method"
        },
        "url" => %{
          "type" => "string",
          "description" => "The URL to request"
        },
        "headers" => %{
          "type" => "object",
          "description" => "HTTP headers as key-value pairs",
          "additionalProperties" => %{"type" => "string"}
        },
        "body" => %{
          "type" => "string",
          "description" => "Request body (for POST/PUT/PATCH)"
        }
      },
      "required" => ["method", "url"]
    }
  end

  @impl true
  def required_credential_type, do: :api_key

  def bucket_for_input(%{"method" => method}) when method in ["GET", "HEAD"], do: :web_access
  def bucket_for_input(_), do: :data_write

  @impl true
  def execute(input, context) do
    method_str = String.downcase(input["method"] || "")

    with true <- method_str in @valid_methods,
         :ok <- OneAgent.Tools.UrlValidator.validate(input["url"]) do
      do_request(String.to_existing_atom(method_str), input, context)
    else
      false ->
        {:error, "Invalid HTTP method: #{input["method"]}. Must be one of: GET, HEAD, POST, PUT, PATCH, DELETE"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(method, input, context) do
    url = input["url"]
    headers = build_headers(input["headers"] || %{}, context)
    body = input["body"]

    opts = [headers: headers, receive_timeout: @request_timeout]
    opts = if body, do: Keyword.put(opts, :body, body), else: opts

    case Req.request([method: method, url: url] ++ opts) do
      {:ok, %Req.Response{status: status, body: resp_body, headers: resp_headers}} ->
        {:ok, %{
          "status" => status,
          "body" => truncate_body(resp_body),
          "headers" => Map.new(resp_headers, fn {k, v} -> {k, List.first(List.wrap(v))} end)
        }}

      {:error, %{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_headers(headers, context) do
    # Inject credential as Authorization header if provided
    case context[:credential_value] do
      nil -> Enum.into(headers, [])
      api_key -> [{"authorization", "Bearer #{api_key}"} | Enum.into(headers, [])]
    end
  end

  defp truncate_body(body) when is_binary(body) do
    OneAgent.TextUtils.truncate_bytes(body, 50_000)
  end

  defp truncate_body(body) when is_map(body) do
    body |> Jason.encode!() |> truncate_body()
  end

  defp truncate_body(body), do: inspect(body)
end
