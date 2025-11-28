defmodule CdRobot.Repo.Migrations.CreateTracks do
  use Ecto.Migration

  def change do
    create table(:tracks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :track_number, :integer
      add :title, :string
      add :artist, :string
      add :duration_seconds, :integer
      add :disk_id, references(:disks, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:tracks, [:disk_id])
    create unique_index(:tracks, [:disk_id, :track_number])
  end
end
