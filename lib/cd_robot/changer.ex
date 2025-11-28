defmodule CdRobot.Changer do
  @moduledoc """
  The Changer context for managing CD changer slots and operations.
  """

  import Ecto.Query, warn: false
  alias CdRobot.Repo
  alias CdRobot.Changer.Slot

  @doc """
  Returns the list of slots with preloaded disks.
  """
  def list_slots do
    Slot
    |> order_by(:slot_number)
    |> preload(disk: [:tracks])
    |> Repo.all()
  end

  @doc """
  Gets a single slot.
  """
  def get_slot!(id), do: Repo.get!(Slot, id) |> Repo.preload(disk: [:tracks])

  @doc """
  Gets a slot by slot number.
  """
  def get_slot_by_number(slot_number) do
    Repo.get_by(Slot, slot_number: slot_number)
    |> case do
      nil -> nil
      slot -> Repo.preload(slot, disk: [:tracks])
    end
  end

  @doc """
  Creates a slot.
  """
  def create_slot(attrs \\ %{}) do
    %Slot{}
    |> Slot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a slot.
  """
  def update_slot(%Slot{} = slot, attrs) do
    slot
    |> Slot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a slot.
  """
  def delete_slot(%Slot{} = slot) do
    Repo.delete(slot)
  end

  @doc """
  Loads a disk into a slot.
  """
  def load_disk(slot_number, disk_id) do
    case get_slot_by_number(slot_number) do
      nil ->
        create_slot(%{slot_number: slot_number, disk_id: disk_id})

      slot ->
        update_slot(slot, %{disk_id: disk_id})
    end
  end

  @doc """
  Unloads a disk from a slot.
  """
  def unload_disk(slot_number) do
    case get_slot_by_number(slot_number) do
      nil -> {:error, :slot_not_found}
      slot -> update_slot(slot, %{disk_id: nil})
    end
  end

  @doc """
  Initialize all slots (1-101 by default).
  """
  def initialize_slots(max_slots \\ 101) do
    Repo.transaction(fn ->
      for slot_number <- 1..max_slots do
        case get_slot_by_number(slot_number) do
          nil -> create_slot(%{slot_number: slot_number})
          _slot -> :ok
        end
      end
    end)
  end
end
