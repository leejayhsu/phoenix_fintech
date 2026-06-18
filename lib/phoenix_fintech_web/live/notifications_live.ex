defmodule PhoenixFintechWeb.NotificationsLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Notifications

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()

    current_user = socket.assigns.current_user

    if current_user do
      notifications = Notifications.list_notifications_for_user(current_user.id, limit: 50)
      unread_count = Notifications.unread_count(current_user.id)

      {:ok,
       socket
       |> assign(:page_title, "Notifications")
       |> stream(:notifications, notifications, reset: true)
       |> assign(:notifications_empty?, notifications == [])
       |> assign(:notifications_unread_count, unread_count)}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    notification = Notifications.get_notification!(id)

    if is_nil(notification.read_at) do
      {:ok, updated} = Notifications.mark_as_read(notification)

      {:noreply,
       socket
       |> stream_insert(:notifications, updated)
       |> assign(
         :notifications_unread_count,
         max(socket.assigns.notifications_unread_count - 1, 0)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    %{current_user: user} = socket.assigns

    Notifications.mark_all_as_read(user.id)
    notifications = Notifications.list_notifications_for_user(user.id, limit: 50)

    {:noreply,
     socket
     |> stream(:notifications, notifications, reset: true)
     |> assign(:notifications_unread_count, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      notifications_unread_count={@notifications_unread_count}
    >
      <section id="notifications-index" class="mx-auto max-w-3xl">
        <div class="mb-6 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Notifications</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Updates about your parties and transfers.
            </p>
          </div>
          <.button
            phx-click="mark_all_read"
            disabled={@notifications_unread_count == 0}
            variant="ghost"
            id="mark-all-read-button"
          >
            Mark all as read
          </.button>
        </div>

        <div class="card card-border bg-base-100">
          <div class="card-body p-0">
            <div id="notifications" phx-update="stream">
              <div
                :if={@notifications_empty?}
                class="px-4 py-8 text-center text-sm text-base-content/60"
              >
                No notifications yet.
              </div>

              <div
                :for={{dom_id, notification} <- @streams.notifications}
                id={dom_id}
                class="flex items-start gap-3 border-b border-base-300 p-4 last:border-b-0"
              >
                <span class={[
                  "mt-1.5 size-2 shrink-0 rounded-full",
                  if(notification.read_at, do: "bg-base-300", else: "bg-primary")
                ]}>
                </span>

                <div class="min-w-0 flex-1">
                  <p class="text-sm leading-snug">{notification.message}</p>
                  <p class="mt-1 text-xs text-base-content/50">
                    {format_timestamp(notification.inserted_at)}
                  </p>

                  <div class="mt-2 flex items-center gap-2">
                    <.link
                      :if={cta_path(notification)}
                      navigate={cta_path(notification)}
                      class="link link-primary text-xs"
                    >
                      View details
                    </.link>

                    <button
                      :if={is_nil(notification.read_at)}
                      type="button"
                      class="btn btn-ghost btn-xs"
                      phx-click="mark_read"
                      phx-value-id={notification.id}
                    >
                      Mark as read
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket) do
    assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
  end

  defp cta_path(notification), do: Notifications.cta_path(notification)

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y · %H:%M")
  end

  defp format_timestamp(_), do: ""
end
