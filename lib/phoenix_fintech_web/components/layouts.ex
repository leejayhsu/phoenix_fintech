defmodule PhoenixFintechWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PhoenixFintechWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil
  attr :section, :atom, default: :app
  attr :admin_resources, :list, default: []
  attr :admin_resource, :map, default: nil
  attr :admin_compliance_pending_count, :integer, default: nil
  attr :notifications_unread_count, :integer, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :profile_name, profile_name(assigns[:current_user]))

    ~H"""
    <div class="min-h-screen bg-base-200 text-base-content">
      <%= if @current_user do %>
        <div class="flex h-screen overflow-hidden">
          <aside class="hidden h-screen w-64 shrink-0 border-r border-base-300 bg-base-100 p-2 lg:flex lg:flex-col">
            <a
              href={if @section == :admin, do: ~p"/admin", else: ~p"/app"}
              class="mb-4 flex items-center gap-2 rounded-lg px-2 py-2 text-sm font-medium tracking-tight transition-colors hover:bg-base-200"
            >
              <span class="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-content">
                <.icon name="hero-banknotes" class="size-4" />
              </span>
              <span>Phoenix Fintech</span>
            </a>

            <%= if @section == :admin do %>
              <div class="px-2 pb-2 text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Workflow
              </div>
              <ul class="menu menu-sm gap-1 p-0 text-sm">
                <li>
                  <.link
                    navigate={~p"/admin/compliance_reviews"}
                    class="flex items-center justify-between gap-2 rounded-lg px-2 py-2 font-medium"
                  >
                    <span class="flex items-center gap-2">
                      <.icon name="hero-shield-check" class="size-4" /> Compliance reviews
                    </span>
                    <span :if={@admin_compliance_pending_count} class="badge badge-warning badge-sm">
                      {@admin_compliance_pending_count}
                    </span>
                  </.link>
                </li>
              </ul>

              <div class="mt-4 px-2 pb-2 text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Resources
              </div>
              <ul class="menu menu-sm gap-1 p-0 text-sm">
                <li :for={resource <- @admin_resources}>
                  <.link
                    navigate={~p"/admin/#{resource.key}"}
                    class={[
                      "rounded-lg px-2 py-2 font-medium",
                      @admin_resource && @admin_resource.key == resource.key && "menu-active"
                    ]}
                  >
                    {resource.label}
                  </.link>
                </li>
              </ul>
            <% else %>
              <ul class="menu menu-sm gap-1 p-0 text-sm">
                <li>
                  <.link navigate={~p"/app"} class="gap-2 rounded-lg px-2 py-2 font-medium">
                    <.icon name="hero-home" class="size-4" /> Dashboard
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/app/parties"} class="gap-2 rounded-lg px-2 py-2 font-medium">
                    <.icon name="hero-building-office-2" class="size-4" /> Parties
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/app/transfers"} class="gap-2 rounded-lg px-2 py-2 font-medium">
                    <.icon name="hero-arrows-right-left" class="size-4" /> Transfers
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/users/settings"} class="gap-2 rounded-lg px-2 py-2 font-medium">
                    <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/app/notifications"}
                    class="flex items-center justify-between gap-2 rounded-lg px-2 py-2 font-medium"
                  >
                    <span class="flex items-center gap-2">
                      <.icon name="hero-bell" class="size-4" /> Notifications
                    </span>
                    <span
                      :if={@notifications_unread_count && @notifications_unread_count > 0}
                      class="badge badge-error badge-sm"
                    >
                      {@notifications_unread_count}
                    </span>
                  </.link>
                </li>
              </ul>
            <% end %>

            <details class="dropdown dropdown-top mt-auto w-full">
              <summary class="flex cursor-pointer list-none items-center gap-2 rounded-lg p-2 text-left transition-colors hover:bg-base-200">
                <div class="avatar avatar-placeholder">
                  <div class="size-8 rounded-lg bg-neutral text-neutral-content">
                    <span class="text-xs font-medium">{String.first(@profile_name)}</span>
                  </div>
                </div>
                <div class="min-w-0 flex-1">
                  <div class="truncate text-sm font-medium leading-tight">{@profile_name}</div>
                  <div class="truncate text-xs text-base-content/60">{@current_user.email}</div>
                </div>
                <.icon name="hero-chevron-up-down" class="size-4 shrink-0 text-base-content/60" />
              </summary>
              <ul class="menu dropdown-content z-10 mb-2 w-full rounded-box border border-base-300 bg-base-100 p-2 shadow">
                <li>
                  <.link navigate={~p"/users/settings"}>
                    <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
                  </.link>
                </li>
                <li :if={@current_user.is_admin && @section != :admin}>
                  <.link navigate={~p"/admin"}>
                    <.icon name="hero-shield-check" class="size-4" /> Admin
                  </.link>
                </li>
                <li :if={@current_user.is_admin && @section == :admin}>
                  <.link navigate={~p"/app"}>
                    <.icon name="hero-arrow-left" class="size-4" /> Back to app
                  </.link>
                </li>
              </ul>
            </details>
          </aside>
          <main class="min-w-0 flex-1 overflow-y-auto p-4">
            {render_slot(@inner_block)}
          </main>
        </div>
      <% else %>
        <main class="px-4 py-16 sm:px-6 lg:px-8">
          <div class="mx-auto max-w-2xl">{render_slot(@inner_block)}</div>
        </main>
      <% end %>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp profile_name(nil), do: "Account"

  defp profile_name(%{email: email}) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.replace([".", "_", "-"], " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp profile_name(_user), do: "Account"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="join">
      <button
        type="button"
        class="btn btn-sm btn-square join-item"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="btn btn-sm btn-square join-item"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="cupcake"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="btn btn-sm btn-square join-item"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dracula"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
