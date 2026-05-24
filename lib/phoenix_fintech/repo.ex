defmodule PhoenixFintech.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_fintech,
    adapter: Ecto.Adapters.Postgres
end
