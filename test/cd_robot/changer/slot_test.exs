defmodule CdRobot.Changer.SlotTest do
  use CdRobot.DataCase

  alias CdRobot.Catalog.Disk
  alias CdRobot.Changer.Slot

  setup do
    {:ok, disk} =
      Repo.insert(
        Disk.changeset(%Disk{}, %{
          disc_id: "810b9e0c",
          title: "Abbey Road",
          artist: "The Beatles"
        })
      )

    %{disk: disk}
  end

  describe "slot changeset" do
    test "valid changeset with slot_number only" do
      attrs = %{slot_number: 1}
      changeset = Slot.changeset(%Slot{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with slot_number and disk_id", %{disk: disk} do
      attrs = %{slot_number: 1, disk_id: disk.id}
      changeset = Slot.changeset(%Slot{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without slot_number" do
      attrs = %{}
      changeset = Slot.changeset(%Slot{}, attrs)
      refute changeset.valid?
      assert %{slot_number: ["can't be blank"]} = errors_on(changeset)
    end

    test "unique constraint on slot_number" do
      attrs = %{slot_number: 1}
      {:ok, _slot} = Repo.insert(Slot.changeset(%Slot{}, attrs))

      {:error, changeset} =
        Repo.insert(Slot.changeset(%Slot{}, attrs))

      assert %{slot_number: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows nil disk_id for empty slot" do
      attrs = %{slot_number: 1, disk_id: nil}
      changeset = Slot.changeset(%Slot{}, attrs)
      assert changeset.valid?

      {:ok, slot} = Repo.insert(changeset)
      assert is_nil(slot.disk_id)
    end

    test "can update empty slot to contain a disk", %{disk: disk} do
      {:ok, slot} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 1}))

      {:ok, updated_slot} =
        slot
        |> Slot.changeset(%{disk_id: disk.id})
        |> Repo.update()

      assert updated_slot.disk_id == disk.id
    end

    test "can update slot to remove a disk", %{disk: disk} do
      {:ok, slot} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 1, disk_id: disk.id}))

      {:ok, updated_slot} =
        slot
        |> Slot.changeset(%{disk_id: nil})
        |> Repo.update()

      assert is_nil(updated_slot.disk_id)
    end
  end

  describe "slot associations" do
    test "belongs_to disk association" do
      assert %Ecto.Association.BelongsTo{} = Slot.__schema__(:association, :disk)
    end
  end

  describe "slot and disk relationship" do
    test "can preload disk from slot", %{disk: disk} do
      {:ok, slot} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 1, disk_id: disk.id}))

      slot_with_disk = Repo.preload(slot, :disk)
      assert slot_with_disk.disk.id == disk.id
      assert slot_with_disk.disk.title == "Abbey Road"
    end

    test "can preload slot from disk", %{disk: disk} do
      {:ok, _slot} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 1, disk_id: disk.id}))

      disk_with_slot = Repo.preload(disk, :slot)
      assert disk_with_slot.slot.slot_number == 1
    end

    test "multiple disks can be in different slots", %{disk: disk1} do
      {:ok, disk2} =
        Repo.insert(
          Disk.changeset(%Disk{}, %{
            disc_id: "abc123",
            title: "Another Album"
          })
        )

      {:ok, slot1} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 1, disk_id: disk1.id}))

      {:ok, slot2} =
        Repo.insert(Slot.changeset(%Slot{}, %{slot_number: 2, disk_id: disk2.id}))

      assert slot1.disk_id == disk1.id
      assert slot2.disk_id == disk2.id
    end
  end
end
