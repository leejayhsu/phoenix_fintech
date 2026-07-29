defmodule PhoenixFintechWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PhoenixFintechWeb, :html

  embed_templates "page_html/*"

  def transfer_status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()

  def transfer_status_badge_classes(status)
      when status in ["completed", "disbursement_settled"],
      do: "badge badge-success badge-soft"

  def transfer_status_badge_classes(status)
      when status in ["compliance_rejected", "cancelled"],
      do: "badge badge-error badge-soft"

  def transfer_status_badge_classes(status)
      when status in ["deposit_pending", "disbursement_pending", "disbursement_initiated"],
      do: "badge badge-warning badge-soft"

  def transfer_status_badge_classes(_status), do: "badge badge-info badge-soft"

  attr :points, :list, required: true
  attr :bar_class, :string, required: true
  attr :value_formatter, :any, default: nil

  def mini_bar_chart(assigns) do
    ~H"""
    <div class="mt-2 flex h-20 items-end gap-2" role="img" aria-label="Seven day trend">
      <div :for={point <- @points} class="flex h-full min-w-0 flex-1 flex-col justify-end gap-1">
        <div
          class={[
            "w-full rounded-t-sm transition-all",
            if(point.percent == 0, do: "bg-base-300", else: @bar_class)
          ]}
          style={"height: #{max(point.percent, 3)}%"}
          title={chart_point_title(point, @value_formatter)}
        >
        </div>
        <span class="text-center text-[0.65rem] text-base-content/50">{point.label}</span>
      </div>
    </div>
    """
  end

  defp chart_point_title(point, nil), do: "#{point.label}: #{point.value}"
  defp chart_point_title(point, formatter), do: "#{point.label}: #{formatter.(point.value)}"
end
