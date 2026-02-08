defmodule OneAgent.Tools.WebSearchTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.WebSearch

  describe "callbacks" do
    test "id returns web_search" do
      assert WebSearch.id() == "web_search"
    end

    test "bucket returns :web_search" do
      assert WebSearch.bucket() == :web_search
    end

    test "required_credential_type returns :api_key" do
      assert WebSearch.required_credential_type() == :api_key
    end

    test "parameters_schema requires query" do
      schema = WebSearch.parameters_schema()
      assert schema["required"] == ["query"]
      assert Map.has_key?(schema["properties"], "query")
      assert Map.has_key?(schema["properties"], "max_results")
      assert Map.has_key?(schema["properties"], "search_depth")
      assert Map.has_key?(schema["properties"], "include_domains")
      assert Map.has_key?(schema["properties"], "exclude_domains")
    end
  end

  describe "execute/2" do
    test "returns error when no credential" do
      context = %{credential_value: nil}
      assert {:error, msg} = WebSearch.execute(%{"query" => "test"}, context)
      assert msg =~ "No Tavily API key"
    end

    test "returns error for missing query" do
      context = %{credential_value: "fake-key"}
      assert {:error, msg} = WebSearch.execute(%{}, context)
      assert msg =~ "Missing required parameter: query"
    end

    test "returns error for empty query" do
      context = %{credential_value: "fake-key"}
      assert {:error, msg} = WebSearch.execute(%{"query" => ""}, context)
      assert msg =~ "Missing required parameter: query"
    end

    test "returns error for whitespace-only query" do
      context = %{credential_value: "fake-key"}
      assert {:error, msg} = WebSearch.execute(%{"query" => "   "}, context)
      assert msg =~ "Missing required parameter: query"
    end

    test "returns error for query exceeding max length" do
      context = %{credential_value: "fake-key"}
      long_query = String.duplicate("a", 2001)
      assert {:error, msg} = WebSearch.execute(%{"query" => long_query}, context)
      assert msg =~ "Query too long"
      assert msg =~ "2001"
    end
  end
end
