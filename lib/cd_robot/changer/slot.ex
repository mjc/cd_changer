defmodule CdRobot.Changer.Slot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "slots" do
    field :slot_number, :integer
    belongs_to :disk, CdRobot.Catalog.Disk, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:slot_number, :disk_id])
    |> validate_required([:slot_number])
    |> unique_constraint(:slot_number)
    |> foreign_key_constraint(:disk_id, name: "slots_disk_id_fkey")
  end
end
