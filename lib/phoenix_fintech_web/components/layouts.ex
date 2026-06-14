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

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :profile_name, profile_name(assigns[:current_user]))

    ~H"""
    <div class="min-h-screen bg-base-200 text-base-content">
      <%= if @current_user do %>
        <div class="flex min-h-screen">
          <aside class="hidden w-72 border-r border-base-300 bg-base-100/95 p-4 shadow-sm lg:flex lg:flex-col">
            <a
              href={~p"/app"}
              class="mb-8 flex items-center gap-3 rounded-box px-3 py-3 text-xl font-semibold tracking-tight transition-colors hover:bg-base-200"
            >
              <span class="flex size-10 items-center justify-center rounded-box bg-primary/10 text-primary">
                <.icon name="hero-banknotes" class="size-6" />
              </span>
              <span>Phoenix Fintech</span>
            </a>
            <ul class="menu menu-lg gap-2 p-0">
              <li>
                <.link navigate={~p"/app"} class="gap-3 rounded-box px-4 py-3 font-medium">
                  <.icon name="hero-home" class="size-5" /> Dashboard
                </.link>
              </li>
              <li>
                <.link navigate={~p"/app/parties"} class="gap-3 rounded-box px-4 py-3 font-medium">
                  <.icon name="hero-building-office-2" class="size-5" /> Parties
                </.link>
              </li>
              <li>
                <.link navigate={~p"/users/settings"} class="gap-3 rounded-box px-4 py-3 font-medium">
                  <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
                </.link>
              </li>
            </ul>
            <.link
              navigate={~p"/users/settings"}
              class="mt-auto flex items-center gap-3 rounded-box border border-base-300 bg-base-100 p-3 text-left shadow-sm transition-colors hover:bg-base-200"
            >
              <div class="avatar avatar-placeholder">
                <div class="size-11 rounded-box bg-neutral text-neutral-content">
                  <span class="text-base font-semibold">{String.first(@profile_name)}</span>
                </div>
              </div>
              <div class="min-w-0 flex-1">
                <div class="truncate text-base font-semibold leading-tight">{@profile_name}</div>
                <div class="truncate text-sm text-base-content/60">{@current_user.email}</div>
              </div>
              <.icon name="hero-chevron-up-down" class="size-5 shrink-0 text-base-content/60" />
            </.link>
          </aside>
          <main class="flex-1 p-6 lg:p-10">
            <div class="mb-6 flex justify-end">
              <.theme_toggle />
            </div>
            {render_slot(@inner_block)}
          </main>
        </div>
      <% else %>
        <main class="px-4 py-16 sm:px-6 lg:px-8">
          <div class="mx-auto mb-6 flex max-w-2xl justify-end">
            <.theme_toggle />
          </div>
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
        data-phx-theme="corporate"
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
