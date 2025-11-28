defmodule CdRobot.Repo do
  use Ecto.Repo,
    otp_app: :cd_robot,
    adapter: Ecto.Adapters.SQLite3
end
