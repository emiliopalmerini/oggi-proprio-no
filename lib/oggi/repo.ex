defmodule Oggi.Repo do
  use Ecto.Repo,
    otp_app: :oggi,
    adapter: Ecto.Adapters.SQLite3
end
