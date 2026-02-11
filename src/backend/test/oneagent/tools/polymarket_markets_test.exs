defmodule OneAgent.Tools.PolymarketMarketsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.PolymarketMarkets

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is polymarket_markets" do
      assert PolymarketMarkets.id() == "polymarket_markets"
    end

    test "bucket is :polymarket" do
      assert PolymarketMarkets.bucket() == :polymarket
    end

    test "required_credential_type is nil" do
      assert PolymarketMarkets.required_credential_type() == nil
    end

    test "parameters_schema has required action field" do
      schema = PolymarketMarkets.parameters_schema()
      assert schema["required"] == ["action"]
      assert schema["properties"]["action"]["enum"] == ["search", "get_event", "get_market", "get_price", "get_book"]
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "invalid"}, context)
      assert msg =~ "Unknown action"
    end

    test "rejects search with missing query", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "search"}, context)
      assert msg =~ "Missing required parameter: query"
    end

    test "rejects search with empty query", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "search", "query" => ""}, context)
      assert msg =~ "Missing required parameter: query"
    end

    test "rejects get_event with missing event_id", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "get_event"}, context)
      assert msg =~ "Missing required parameter: event_id"
    end

    test "rejects get_market with missing market_id", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "get_market"}, context)
      assert msg =~ "Missing required parameter: market_id"
    end

    test "rejects get_price with missing token_id", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "get_price"}, context)
      assert msg =~ "Missing required parameter: token_id"
    end

    test "rejects get_book with missing token_id", %{context: context} do
      assert {:error, msg} = PolymarketMarkets.execute(%{"action" => "get_book"}, context)
      assert msg =~ "Missing required parameter: token_id"
    end
  end
end
