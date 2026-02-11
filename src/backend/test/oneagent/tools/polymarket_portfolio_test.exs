defmodule OneAgent.Tools.PolymarketPortfolioTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.PolymarketPortfolio

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is polymarket_portfolio" do
      assert PolymarketPortfolio.id() == "polymarket_portfolio"
    end

    test "bucket is :polymarket" do
      assert PolymarketPortfolio.bucket() == :polymarket
    end

    test "required_credential_type is :custom" do
      assert PolymarketPortfolio.required_credential_type() == :custom
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      assert {:error, msg} = PolymarketPortfolio.execute(%{"action" => "invalid"}, context)
      assert msg =~ "Unknown action"
    end

    test "rejects positions with no credential", %{context: context} do
      assert {:error, msg} = PolymarketPortfolio.execute(%{"action" => "positions"}, context)
      assert msg =~ "No Polymarket credential"
    end

    test "rejects with invalid credential JSON", %{context: context} do
      ctx = Map.put(context, :credential_value, "bad json")
      assert {:error, msg} = PolymarketPortfolio.execute(%{"action" => "positions"}, ctx)
      assert msg =~ "Invalid credential JSON"
    end

    test "rejects with missing private_key in credential", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"not_key" => "val"}))
      assert {:error, msg} = PolymarketPortfolio.execute(%{"action" => "positions"}, ctx)
      assert msg =~ "Invalid credential format"
    end
  end
end
