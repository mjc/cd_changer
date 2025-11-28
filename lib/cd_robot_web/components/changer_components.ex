defmodule CdRobotWeb.ChangerComponents do
  @moduledoc """
  Shared components for the CD Changer application.
  """
  use Phoenix.Component
  import CdRobotWeb.CoreComponents

  # Import verified routes for ~p sigil
  use CdRobotWeb, :verified_routes

  @doc """
  Renders the navigation header with changer status and view switcher.

  ## Examples

      <.nav_header slots={@slots} current_path={~p"/"} />
  """
  attr :slots, :list, required: true
  attr :current_path, :string, required: true

  def nav_header(assigns) do
    ~H"""
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

      <div class="grid grid-cols-3 gap-2">
        <.link
          navigate={~p"/"}
          class={[
            "px-4 py-3 rounded-lg font-semibold transition-all text-center",
            if(@current_path == "/",
              do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
              else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
            )
          ]}
        >
          <.icon name="hero-musical-note" class="w-5 h-5 inline mr-2" />
          Albums
        </.link>
        <.link
          navigate={~p"/load"}
          class={[
            "px-4 py-3 rounded-lg font-semibold transition-all text-center",
            if(@current_path == "/load",
              do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
              else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
            )
          ]}
        >
          <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" />
          Load Album
        </.link>
        <.link
          navigate={~p"/add"}
          class={[
            "px-4 py-3 rounded-lg font-semibold transition-all text-center",
            if(@current_path == "/add",
              do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
              else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
            )
          ]}
        >
          <.icon name="hero-plus" class="w-5 h-5 inline mr-2" />
          Add New CD
        </.link>
      </div>
    </div>
    """
  end
end
