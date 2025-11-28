defmodule CdRobot.Repo.Migrations.CreateSlots do
  use Ecto.Migration

  def change do
    create table(:slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slot_number, :integer
      add :disk_id, references(:disks, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:slots, [:slot_number])
    create index(:slots, [:disk_id])
  end
end
