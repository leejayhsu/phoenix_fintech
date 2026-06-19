defmodule PhoenixFintechWeb.NotificationBadgeLive do
  @moduledoc """
  A self-contained LiveView that renders the unread notifications count badge
  and updates in real time via PubSub when notifications are created or read.

  Rendered inside `Layouts.app` via `live_render/3`, so it stays mounted across
  page navigations and works on both LiveView and controller-rendered pages.
  """
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Notifications
  alias PhoenixFintech.PubSub

  @impl true
  def mount(_params, %{"current_user_id" => user_id}, socket) do
    Phoenix.PubSub.subscribe(PubSub, Notifications.topic(user_id))

    {:ok, assign(socket, :unread_count, Notifications.unread_count(user_id))}
  end

  @impl true
  def handle_info({:notification_created, _notification}, socket) do
    {:noreply, update(socket, :unread_count, &(&1 + 1))}
  end

  def handle_info({:notification_read, _notification}, socket) do
    {:noreply, update(socket, :unread_count, &max(&1 - 1, 0))}
  end

  def handle_info({:notifications_all_read, _user_id}, socket) do
    {:noreply, assign(socket, :unread_count, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @unread_count > 0 do %>
      <span class="badge badge-error badge-sm">{@unread_count}</span>
    <% end %>
    """
  end
end
