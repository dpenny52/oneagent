defmodule OneAgent.Repo do
  use Ecto.Repo,
    otp_app: :oneagent,
    adapter: Ecto.Adapters.Postgres
end
