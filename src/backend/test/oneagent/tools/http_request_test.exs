defmodule OneAgent.Tools.HttpRequestTest do
  use ExUnit.Case, async: true

  alias OneAgent.Tools.HttpRequest

  describe "execute/2" do
    test "rejects invalid HTTP method" do
      assert {:error, msg} = HttpRequest.execute(%{"method" => "TRACE", "url" => "https://example.com"}, %{})
      assert msg =~ "Invalid HTTP method"
    end

    test "rejects URLs that fail SSRF validation" do
      assert {:error, _} = HttpRequest.execute(%{"method" => "GET", "url" => "http://127.0.0.1"}, %{})
    end

    @tag :slow
    test "handles connection error gracefully" do
      result = HttpRequest.execute(%{"method" => "GET", "url" => "http://192.0.2.1:1"}, %{})
      assert {:error, msg} = result
      assert msg =~ "HTTP request failed"
    end
  end

  describe "bucket_for_input/1" do
    test "GET requires web_access" do
      assert :web_access = HttpRequest.bucket_for_input(%{"method" => "GET"})
    end

    test "HEAD requires web_access" do
      assert :web_access = HttpRequest.bucket_for_input(%{"method" => "HEAD"})
    end

    test "POST requires data_write" do
      assert :data_write = HttpRequest.bucket_for_input(%{"method" => "POST"})
    end

    test "PUT requires data_write" do
      assert :data_write = HttpRequest.bucket_for_input(%{"method" => "PUT"})
    end

    test "DELETE requires data_write" do
      assert :data_write = HttpRequest.bucket_for_input(%{"method" => "DELETE"})
    end
  end
end
