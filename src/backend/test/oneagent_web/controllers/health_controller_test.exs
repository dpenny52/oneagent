defmodule OneAgentWeb.HealthControllerTest do
  use OneAgentWeb.ConnCase, async: true

  test "GET /api/health returns ok", %{conn: conn} do
    conn = get(conn, ~p"/api/health")
    assert %{"status" => "ok"} = json_response(conn, 200)
  end
end
