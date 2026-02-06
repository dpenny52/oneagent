defmodule OneAgentWeb.HealthController do
  use OneAgentWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
