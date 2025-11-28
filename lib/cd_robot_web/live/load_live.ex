defmodule CdRobotWeb.LoadLive do
  use CdRobotWeb, :live_view
  import CdRobotWeb.ChangerComponents
  alias CdRobot.{Changer, Catalog}

  @impl true
  def mount(_params, _session, socket) do
    slots = Changer.list_slots()

    {:ok,
     socket
     |> assign(:slots, slots)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:page_title, "Load Album")}
  end

  @impl true
  def handle_event("search_disks", %{"search" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Catalog.search_disks(query)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  def handle_event(
        "load_disk_to_slot",
        %{"disk_id" => disk_id, "slot_number" => slot_number},
        socket
      ) do
    slot_number = String.to_integer(slot_number)

    case Changer.load_disk(slot_number, disk_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:slots, Changer.list_slots())
         |> assign(:search_query, "")
         |> assign(:search_results, [])
         |> put_flash(:info, "Album loaded into slot #{slot_number}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load album")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 p-4">
      <div class="max-w-7xl mx-auto">
        <.nav_header slots={@slots} current_path="/load" />

        <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
          <form phx-change="search_disks" class="mb-6">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500"
              />
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Search for an album or artist to load..."
                autocomplete="off"
                class="w-full pl-12 pr-4 py-3 bg-slate-900 border border-slate-600 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </form>

          <%= if @search_query != "" do %>
            <%= if @search_results == [] do %>
              <div class="text-center py-12 text-slate-500">
                <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-3 opacity-50" />
                <p>No albums found matching "<%= @search_query %>"</p>
              </div>
            <% else %>
              <div class="mb-8">
                <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
                  Search Results
                </h3>
                <div class="grid grid-cols-1 gap-3">
                  <%= for disk <- @search_results do %>
                    <div class="bg-slate-900/60 rounded-lg p-4 border border-slate-700">
                      <div class="flex items-center gap-4 mb-3">
                        <%= if disk.cover_art_url do %>
                          <img
                            src={disk.cover_art_url}
                            alt={disk.title}
                            class="w-16 h-16 object-cover rounded shadow-lg"
                          />
                        <% else %>
                          <div class="w-16 h-16 bg-slate-800 rounded flex items-center justify-center">
                            <.icon name="hero-musical-note" class="w-8 h-8 text-slate-600" />
                          </div>
                        <% end %>
                        <div class="flex-1 min-w-0">
                          <h3 class="font-bold text-white truncate">
                            <%= disk.title || "Unknown Album" %>
                          </h3>
                          <p class="text-sm text-slate-300 truncate">
                            <%= disk.artist || "Unknown Artist" %>
                          </p>
                          <%= if disk.year do %>
                            <p class="text-xs text-slate-500"><%= disk.year %></p>
                          <% end %>
                        </div>
                      </div>
                      <div>
                        <p class="text-xs text-slate-400 mb-2">
                          Select an empty slot to load this album:
                        </p>
                        <div class="flex flex-wrap gap-1">
                          <%= for slot <- Enum.filter(@slots, &(is_nil(&1.disk_id))) |> Enum.take(10) do %>
                            <button
                              phx-click="load_disk_to_slot"
                              phx-value-disk_id={disk.id}
                              phx-value-slot_number={slot.slot_number}
                              class="px-3 py-1 bg-blue-600 hover:bg-blue-500 text-white text-sm rounded font-medium transition-colors"
                            >
                              <%= slot.slot_number %>
                            </button>
                          <% end %>
                          <%= if Enum.count(@slots, &is_nil(&1.disk_id)) > 10 do %>
                            <span class="px-3 py-1 text-slate-500 text-sm">
                              +<%= Enum.count(@slots, &is_nil(&1.disk_id)) - 10 %> more
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>

          <div>
            <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
              Empty Slots (<%= Enum.count(@slots, &is_nil(&1.disk_id)) %>)
            </h3>
            <%= if Enum.any?(@slots, &is_nil(&1.disk_id)) do %>
              <div class="grid grid-cols-8 sm:grid-cols-12 md:grid-cols-17 gap-2">
                <%= for slot <- @slots, is_nil(slot.disk_id) do %>
                  <div class="aspect-square rounded-lg bg-slate-700/50 border border-slate-600 flex items-center justify-center text-slate-400 text-sm font-medium">
                    <%= slot.slot_number %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-12 text-slate-500">
                <.icon name="hero-check-circle" class="w-12 h-12 mx-auto mb-3 opacity-50" />
                <p>All slots are loaded!</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
