defmodule CdRobotWeb.ChangerLive do
  use CdRobotWeb, :live_view
  alias CdRobot.{Changer, Catalog}

  @impl true
  def mount(_params, _session, socket) do
    slots = Changer.list_slots()

    {:ok,
     socket
     |> assign(:slots, slots)
     |> assign(:view_mode, :albums)
     |> assign(:selected_disk, nil)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:page_title, "CD Changer")}
  end

  @impl true
  def handle_event("switch_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_existing_atom(mode))}
  end

  def handle_event("select_disk", %{"disk_id" => disk_id}, socket) do
    slot = Enum.find(socket.assigns.slots, &(&1.disk_id == disk_id))

    {:noreply, assign(socket, selected_disk: slot)}
  end

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
    {:noreply,
     socket
     |> assign(:selected_disk, nil)
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 p-4">
      <div class="max-w-7xl mx-auto">
        <%!-- Header --%>
        <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 mb-6 border border-slate-700">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h1 class="text-3xl font-bold text-white mb-1">CD Changer</h1>
              <p class="text-slate-400">101-Disc Automatic Changer</p>
            </div>
            <div class="text-slate-400">
              <div class="text-sm">Loaded Albums</div>
              <div class="text-2xl font-bold text-white">
                <%= Enum.count(@slots, & &1.disk_id) %> / 101
              </div>
            </div>
          </div>

          <%!-- View Mode Toggle --%>
          <div class="flex gap-2">
            <button
              phx-click="switch_view"
              phx-value-mode="albums"
              class={[
                "flex-1 px-4 py-3 rounded-lg font-semibold transition-all",
                if(@view_mode == :albums,
                  do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
                  else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
                )
              ]}
            >
              <.icon name="hero-musical-note" class="w-5 h-5 inline mr-2" />
              Albums
            </button>
            <button
              phx-click="switch_view"
              phx-value-mode="empty_slots"
              class={[
                "flex-1 px-4 py-3 rounded-lg font-semibold transition-all",
                if(@view_mode == :empty_slots,
                  do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
                  else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
                )
              ]}
            >
              <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" />
              Load Album
            </button>
          </div>
        </div>

        <%= if @view_mode == :albums do %>
          <%!-- Albums View --%>
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
        <% else %>
          <%!-- Empty Slots View --%>
          <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
            <%!-- Search Bar --%>
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
              <%!-- Search Results --%>
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
                        <%!-- Available Slots for this disk --%>
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

            <%!-- Empty Slots Grid --%>
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
        <% end %>
      </div>

      <%!-- Album Details Modal --%>
      <%= if @selected_disk do %>
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
      <% end %>
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
