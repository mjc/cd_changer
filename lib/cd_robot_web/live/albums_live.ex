defmodule CdRobotWeb.AlbumsLive do
  use CdRobotWeb, :live_view
  import CdRobotWeb.ChangerComponents
  alias CdRobot.Changer

  @impl true
  def mount(_params, _session, socket) do
    slots = Changer.list_slots()

    {:ok,
     socket
     |> assign(:slots, slots)
     |> assign(:selected_disk, nil)
     |> assign(:page_title, "Albums")}
  end

  @impl true
  def handle_event("select_disk", %{"disk_id" => disk_id}, socket) do
    slot = Enum.find(socket.assigns.slots, &(&1.disk_id == disk_id))

    {:noreply, assign(socket, selected_disk: slot)}
  end

  def handle_event("unload_disk", %{"slot_number" => slot_number}, socket) do
    slot_number = String.to_integer(slot_number)

    case Changer.unload_disk(slot_number) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:slots, Changer.list_slots())
         |> assign(:selected_disk, nil)
         |> put_flash(:info, "Album unloaded from slot #{slot_number}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unload album")}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :selected_disk, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 p-4">
      <div class="max-w-7xl mx-auto">
        <.nav_header slots={@slots} current_path="/" />

        <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
          <%= if Enum.any?(@slots, & &1.disk_id) do %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              <%= for slot <- @slots, slot.disk do %>
                <button
                  phx-click="select_disk"
                  phx-value-disk_id={slot.disk.id}
                  class="bg-slate-900/60 hover:bg-slate-900 rounded-xl p-4 transition-all border border-slate-700 hover:border-blue-500 hover:shadow-lg hover:shadow-blue-500/20 text-left group"
                >
                  <div class="flex gap-4">
                    <%= if slot.disk.cover_art_url do %>
                      <img
                        src={slot.disk.cover_art_url}
                        alt={slot.disk.title}
                        class="w-20 h-20 object-cover rounded-lg shadow-lg group-hover:shadow-xl transition-shadow"
                      />
                    <% else %>
                      <div class="w-20 h-20 bg-gradient-to-br from-slate-700 to-slate-800 rounded-lg flex items-center justify-center shadow-lg">
                        <.icon name="hero-musical-note" class="w-10 h-10 text-slate-500" />
                      </div>
                    <% end %>
                    <div class="flex-1 min-w-0">
                      <h3 class="font-bold text-white truncate mb-1">
                        <%= slot.disk.title || "Unknown Album" %>
                      </h3>
                      <p class="text-sm text-slate-300 truncate mb-2">
                        <%= slot.disk.artist || "Unknown Artist" %>
                      </p>
                      <div class="flex items-center gap-2 text-xs text-slate-500">
                        <%= if slot.disk.year do %>
                          <span><%= slot.disk.year %></span>
                          <span>•</span>
                        <% end %>
                        <span>Slot <%= slot.slot_number %></span>
                      </div>
                    </div>
                  </div>
                </button>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-16 text-slate-500">
              <.icon name="hero-musical-note" class="w-16 h-16 mx-auto mb-4 opacity-50" />
              <p class="text-xl mb-2">No albums loaded</p>
              <p class="text-sm">Switch to "Load Album" to add albums to your changer</p>
            </div>
          <% end %>
        </div>
      </div>

      <.album_modal :if={@selected_disk} selected_disk={@selected_disk} />
    </div>
    """
  end

  defp album_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      phx-click="close_modal"
    >
      <div
        class="bg-slate-800 rounded-2xl shadow-2xl max-w-2xl w-full border border-slate-700"
        phx-click={JS.exec("phx-remove", to: "#stop-propagation")}
      >
        <div id="stop-propagation" phx-click={JS.exec("phx-remove", to: "#dummy")}>
          <div class="p-6 border-b border-slate-700">
            <div class="flex justify-between items-start">
              <div class="flex gap-4 flex-1">
                <%= if @selected_disk.disk.cover_art_url do %>
                  <img
                    src={@selected_disk.disk.cover_art_url}
                    alt={@selected_disk.disk.title}
                    class="w-32 h-32 object-cover rounded-lg shadow-xl"
                  />
                <% else %>
                  <div class="w-32 h-32 bg-gradient-to-br from-slate-700 to-slate-800 rounded-lg flex items-center justify-center shadow-xl">
                    <.icon name="hero-musical-note" class="w-16 h-16 text-slate-500" />
                  </div>
                <% end %>
                <div class="flex-1">
                  <h2 class="text-2xl font-bold text-white mb-1">
                    <%= @selected_disk.disk.title || "Unknown Album" %>
                  </h2>
                  <p class="text-lg text-slate-300 mb-2">
                    <%= @selected_disk.disk.artist || "Unknown Artist" %>
                  </p>
                  <div class="flex items-center gap-3 text-sm text-slate-400">
                    <%= if @selected_disk.disk.year do %>
                      <span><%= @selected_disk.disk.year %></span>
                    <% end %>
                    <%= if @selected_disk.disk.genre do %>
                      <span>•</span>
                      <span><%= @selected_disk.disk.genre %></span>
                    <% end %>
                    <span>•</span>
                    <span>Slot <%= @selected_disk.slot_number %></span>
                  </div>
                </div>
              </div>
              <button
                phx-click="close_modal"
                class="text-slate-400 hover:text-white transition-colors ml-4"
              >
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>
            </div>
          </div>

          <div class="p-6">
            <%= if @selected_disk.disk.tracks && @selected_disk.disk.tracks != [] do %>
              <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
                Tracks
              </h3>
              <div class="space-y-1 mb-6 max-h-64 overflow-y-auto">
                <%= for track <- Enum.sort_by(@selected_disk.disk.tracks, & &1.track_number) do %>
                  <div class="flex items-center gap-3 px-3 py-2 rounded hover:bg-slate-900/50 transition-colors">
                    <span class="text-slate-500 text-sm font-mono w-6 text-right">
                      <%= track.track_number %>.
                    </span>
                    <span class="flex-1 text-white"><%= track.title %></span>
                    <%= if track.duration_seconds do %>
                      <span class="text-slate-400 text-sm font-mono">
                        <%= format_duration(track.duration_seconds) %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

            <button
              phx-click="unload_disk"
              phx-value-slot_number={@selected_disk.slot_number}
              class="w-full px-4 py-3 bg-red-600 hover:bg-red-500 text-white rounded-lg font-semibold transition-colors shadow-lg hover:shadow-red-500/50"
            >
              <.icon name="hero-trash" class="w-5 h-5 inline mr-2" /> Unload Album
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_duration(_), do: ""
end
