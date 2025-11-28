defmodule CdRobot.Repo.Migrations.CreateDisks do
  use Ecto.Migration

  def change do
    create table(:disks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :artist, :string
      add :genre, :string
      add :year, :integer
      add :disc_id, :string
      add :total_tracks, :integer
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:disks, [:disc_id])
  end
end
