defmodule OneAgentWeb.Plugs.RateLimitTest do
  use OneAgentWeb.ConnCase, async: false

  # async: false because Hammer ETS state is shared

  import OneAgent.AgentsFixtures

  setup :register_and_log_in_user

  setup do
    # Clear Hammer ETS state between tests
    on_exit(fn ->
      try do
        :ets.delete_all_objects(:hammer_backend_ets_buckets)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "invoke rate limiting (10 req/min per user)" do
    test "allows requests under the limit", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      for _ <- 1..10 do
        conn =
          build_conn()
          |> put_req_header("authorization", get_req_header(conn, "authorization") |> hd())
          |> put_req_header("accept", "application/json")
          |> post("/api/agents/#{agent.id}/invoke", %{"message" => "hello"})

        # Should not be 429 (may be 422 if no LLM config, that's fine)
        refute conn.status == 429
      end
    end

    test "blocks requests over the limit with 429", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      auth_header = get_req_header(conn, "authorization") |> hd()

      # Exhaust the 10 request limit
      for _ <- 1..10 do
        build_conn()
        |> put_req_header("authorization", auth_header)
        |> put_req_header("accept", "application/json")
        |> post("/api/agents/#{agent.id}/invoke", %{"message" => "hello"})
      end

      # 11th request should be rate limited
      conn =
        build_conn()
        |> put_req_header("authorization", auth_header)
        |> put_req_header("accept", "application/json")
        |> post("/api/agents/#{agent.id}/invoke", %{"message" => "hello"})

      assert conn.status == 429
      assert %{"error" => "Too many requests." <> _} = json_response(conn, 429)
    end

    test "rate limits are per-user (different users have independent limits)", %{
      conn: conn,
      user: user
    } do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      auth_header1 = get_req_header(conn, "authorization") |> hd()

      # Exhaust user1's limit
      for _ <- 1..10 do
        build_conn()
        |> put_req_header("authorization", auth_header1)
        |> put_req_header("accept", "application/json")
        |> post("/api/agents/#{agent.id}/invoke", %{"message" => "hello"})
      end

      # Create a second user with their own agent
      user2 = OneAgent.AccountsFixtures.confirmed_user_fixture()
      token2 = OneAgent.Accounts.create_user_api_token(user2)
      scope2 = OneAgent.Accounts.Scope.for_user(user2)
      agent2 = agent_fixture(scope2)

      # User2 should NOT be rate limited (independent bucket)
      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token2}")
        |> put_req_header("accept", "application/json")
        |> post("/api/agents/#{agent2.id}/invoke", %{"message" => "hello"})

      refute conn2.status == 429
    end
  end

  describe "OAuth rate limiting (10 req/min per IP)" do
    test "blocks Google OAuth requests over the limit with 429", %{conn: _conn} do
      # Exhaust the 10 request limit on the oauth bucket
      for _ <- 1..10 do
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/auth/google")
      end

      # 11th request should be rate limited
      resp =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/auth/google")

      assert resp.status == 429
      assert %{"error" => "Too many requests." <> _} = json_response(resp, 429)
    end

    test "blocks Gmail OAuth callback requests over the limit with 429", %{conn: _conn} do
      # Exhaust the 10 request limit on the shared oauth bucket
      for _ <- 1..10 do
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/auth/gmail/callback", %{"code" => "fake", "state" => "fake"})
      end

      # 11th request should be rate limited
      resp =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/auth/gmail/callback", %{"code" => "fake", "state" => "fake"})

      assert resp.status == 429
    end
  end

  describe "API rate limiting (60 req/min per user)" do
    test "allows many requests under the limit", %{conn: conn} do
      for _ <- 1..30 do
        resp =
          build_conn()
          |> put_req_header("authorization", get_req_header(conn, "authorization") |> hd())
          |> put_req_header("accept", "application/json")
          |> get("/api/agents")

        assert resp.status == 200
      end
    end

    test "blocks requests over the 60 req/min limit with 429", %{conn: conn} do
      auth_header = get_req_header(conn, "authorization") |> hd()

      # Exhaust the 60 request limit
      for _ <- 1..60 do
        build_conn()
        |> put_req_header("authorization", auth_header)
        |> put_req_header("accept", "application/json")
        |> get("/api/agents")
      end

      # 61st request should be rate limited
      resp =
        build_conn()
        |> put_req_header("authorization", auth_header)
        |> put_req_header("accept", "application/json")
        |> get("/api/agents")

      assert resp.status == 429
    end
  end
end
