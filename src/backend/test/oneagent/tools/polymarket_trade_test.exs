defmodule OneAgent.Tools.PolymarketTradeTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.PolymarketTrade

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is polymarket_trade" do
      assert PolymarketTrade.id() == "polymarket_trade"
    end

    test "bucket is :polymarket" do
      assert PolymarketTrade.bucket() == :polymarket
    end

    test "required_credential_type is :custom" do
      assert PolymarketTrade.required_credential_type() == :custom
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      assert {:error, msg} = PolymarketTrade.execute(%{"action" => "invalid"}, context)
      assert msg =~ "Unknown action"
    end

    test "rejects buy with no credential", %{context: context} do
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 10, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, context)
      assert msg =~ "No Polymarket credential"
    end

    test "rejects buy with invalid credential JSON", %{context: context} do
      ctx = Map.put(context, :credential_value, "not json")
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 10, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid credential JSON"
    end

    test "rejects buy with missing private_key in credential", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"wrong_key" => "0x123"}))
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 10, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid credential format"
    end

    test "rejects buy with missing token_id", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "buy", "amount" => 10, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Missing required parameter: token_id"
    end

    test "rejects buy with zero amount", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 0, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid amount"
    end

    test "rejects buy with negative amount", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "buy", "token_id" => "abc", "amount" => -5, "price" => 0.5}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid amount"
    end

    test "rejects buy with price too low", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 10, "price" => 0.001}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid price"
    end

    test "rejects buy with price too high", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "buy", "token_id" => "abc", "amount" => 10, "price" => 1.0}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Invalid price"
    end

    test "rejects cancel with missing order_id", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc123"}))
      input = %{"action" => "cancel"}
      assert {:error, msg} = PolymarketTrade.execute(input, ctx)
      assert msg =~ "Missing required parameter: order_id"
    end
  end
end
