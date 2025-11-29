defmodule CdRobot.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :cd_robot

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    # Seed the database after migrations
    seed()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          # Initialize slots if they don't exist
          case CdRobot.Changer.list_slots() do
            [] ->
              IO.puts("Initializing 101 slots...")
              CdRobot.Changer.initialize_slots(101)
              IO.puts("Slots initialized successfully")

            slots ->
              IO.puts("#{length(slots)} slots already initialized")
          end

          {:ok, nil, nil}
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
