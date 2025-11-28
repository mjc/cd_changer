defmodule CdRobot.Repo.Migrations.AddCoverArtToDisks do
  use Ecto.Migration

  def change do
    alter table(:disks) do
      add :cover_art_url, :string
    end
  end
end
