defmodule OneAgentWeb.BodySizeLimitTest do
  use OneAgentWeb.ConnCase, async: true

  test "rejects JSON payloads exceeding 1MB", %{conn: conn} do
    large_value = String.duplicate("x", 1_100_000)

    assert_error_sent 413, fn ->
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/auth/register", Jason.encode!(%{"user" => %{"email" => large_value}}))
    end
  end

  test "accepts JSON payloads under 1MB", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/auth/register",
        Jason.encode!(%{
          "user" => %{"email" => "bodysize@example.com", "password" => "testpassword123"}
        })
      )

    refute conn.status == 413
  end
end
