defmodule PhoenixFintechWeb.ComplianceReviewLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Compliance
  alias PhoenixFintech.Compliance.Review
  alias PhoenixFintech.Notifications

  @status_filters [
    %{key: "pending", label: "Pending", statuses: ["created", "manual_review"]},
    %{key: "approved", label: "Approved", statuses: ["approved"]},
    %{key: "rejected", label: "Rejected", statuses: ["rejected"]},
    %{key: "all", label: "All", statuses: nil}
  ]

  @impl true
  def mount(params, _session, socket) do
    pending_count = length(Compliance.list_pending_reviews())

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:current_user, socket.assigns.current_scope.user)
      |> assign(:status_filters, @status_filters)
      |> assign(:admin_compliance_pending_count, pending_count)

    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter_key}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/compliance_reviews?filter=#{filter_key}")}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    review = Compliance.get_review!(id)
    notes = socket.assigns[:review_notes_value]

    case Compliance.approve_review(review, socket.assigns.current_user, notes) do
      {:ok, updated_review} ->
        notify_party_decision(updated_review, :approved)

        {:noreply,
         socket
         |> put_flash(:info, "Compliance review approved.")
         |> push_patch(to: ~p"/admin/compliance_reviews/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply, put_flash(socket, :error, "Unable to approve review: #{inspect(reason)}")}
    end
  end

  def handle_event("reject", %{"id" => id}, socket) do
    review = Compliance.get_review!(id)
    notes = socket.assigns[:review_notes_value]

    case Compliance.reject_review(review, socket.assigns.current_user, notes) do
      {:ok, updated_review} ->
        notify_party_decision(updated_review, :rejected)

        {:noreply,
         socket
         |> put_flash(:info, "Compliance review rejected.")
         |> push_patch(to: ~p"/admin/compliance_reviews/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply, put_flash(socket, :error, "Unable to reject review: #{inspect(reason)}")}
    end
  end

  def handle_event("request_manual_review", %{"id" => id}, socket) do
    review = Compliance.get_review!(id)
    notes = socket.assigns[:review_notes_value]

    case Compliance.request_manual_review(review, socket.assigns.current_user, notes) do
      {:ok, updated_review} ->
        notify_party_decision(updated_review, :manual_review)

        {:noreply,
         socket
         |> put_flash(:info, "Compliance review queued for manual review.")
         |> push_patch(to: ~p"/admin/compliance_reviews/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply,
         put_flash(socket, :error, "Unable to request manual review: #{inspect(reason)}")}
    end
  end

  def handle_event("validate_notes", %{"review_notes" => %{"notes" => notes}}, socket) do
    {:noreply, assign(socket, :review_notes_value, notes)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      section={:admin}
      admin_resources={[]}
    >
      <section id="compliance-reviews" class="mx-auto max-w-6xl">
        <div class="mb-6 flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="text-2xl font-semibold">Compliance reviews</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Approve or reject transfers and originators awaiting compliance review.
            </p>
          </div>
          <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Back to admin
          </.link>
        </div>

        <%= case @live_action do %>
          <% :index -> %>
            <.reviews_index
              status_filters={@status_filters}
              active_filter={@active_filter}
              reviews={@streams.reviews}
              reviews_empty?={@reviews_empty?}
            />
          <% :show -> %>
            <.review_detail
              review={@review}
              notes_form={@notes_form}
              current_user={@current_user}
            />
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  attr :status_filters, :list, required: true
  attr :active_filter, :string, required: true
  attr :reviews, :map, required: true
  attr :reviews_empty?, :boolean, required: true

  defp reviews_index(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-2">
        <.link
          :for={filter <- @status_filters}
          id={"compliance-filter-#{filter.key}"}
          phx-click="set_filter"
          phx-value-filter={filter.key}
          class={[
            "btn btn-sm",
            @active_filter == filter.key && "btn-primary",
            @active_filter != filter.key && "btn-ghost"
          ]}
        >
          {filter.label}
        </.link>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body gap-0 p-0">
          <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
              <thead>
                <tr>
                  <th>Subject</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th>Reviewer</th>
                  <th>Submitted</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="compliance-reviews-table" phx-update="stream">
                <tr :if={@reviews_empty?} id="compliance-reviews-empty">
                  <td colspan="6" class="py-8 text-center text-base-content/60">
                    No compliance reviews found.
                  </td>
                </tr>
                <tr :for={{dom_id, review} <- @reviews} id={dom_id} class="hover">
                  <td>{subject_label(review)}</td>
                  <td>
                    <span class="badge badge-soft badge-sm">{subject_type(review)}</span>
                  </td>
                  <td>{render_status(review.status)}</td>
                  <td>{review.reviewer_name}</td>
                  <td>
                    <time class="text-xs text-base-content/60">
                      {Calendar.strftime(review.submitted_at, "%b %-d, %Y")}
                    </time>
                  </td>
                  <td class="text-right">
                    <.link
                      navigate={~p"/admin/compliance_reviews/#{review.id}"}
                      class="btn btn-xs btn-primary"
                    >
                      Review
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :review, :map, required: true
  attr :notes_form, :map, required: true
  attr :current_user, :map, required: true

  defp review_detail(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="card card-border bg-base-200">
        <div class="card-body gap-4">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-xl font-semibold">{subject_label(@review)}</h2>
              <p class="mt-1 text-sm text-base-content/70">
                Compliance review for {subject_type(@review)} · Reference
                <span class="font-mono">{@review.id}</span>
              </p>
            </div>
            <span class={status_badge_classes(@review.status)}>
              {render_status(@review.status)}
            </span>
          </div>

          <dl class="grid gap-4 sm:grid-cols-2">
            <.detail_row label="Subject type" value={subject_type(@review)} />
            <.detail_row
              label="Subject reference"
              value={subject_reference(@review)}
            />
            <.detail_row
              label="Reviewer"
              value={reviewer_label(@review.reviewed_by_user)}
            />
            <.detail_row
              label="Submitted"
              value={Calendar.strftime(@review.inserted_at, "%B %-d, %Y %-I:%M %p")}
            />
          </dl>
        </div>
      </div>

      <%= if subject_type(@review) == "Transfer" do %>
        <div class="card card-border bg-base-100">
          <div class="card-body">
            <h3 class="card-title text-base">Transfer summary</h3>
            <.transfer_summary transfer={@review.transfer} />
          </div>
        </div>
      <% else %>
        <div class="card card-border bg-base-100">
          <div class="card-body">
            <h3 class="card-title text-base">Party summary</h3>
            <.party_summary party={@review.party} />
          </div>
        </div>
      <% end %>

      <div class="card card-border bg-base-100">
        <div class="card-body gap-4">
          <div>
            <h3 class="card-title text-base">Decision</h3>
            <p class="mt-1 text-sm text-base-content/70">
              Optionally leave a note before approving, rejecting, or sending the review back for manual review.
            </p>
          </div>

          <.form
            for={@notes_form}
            id="compliance-review-notes-form"
            phx-change="validate_notes"
            class="grid gap-3"
          >
            <.input
              field={@notes_form[:notes]}
              type="textarea"
              label="Reviewer notes"
              placeholder="Optional context for the decision."
            />
          </.form>

          <div class="flex flex-wrap gap-2">
            <button
              :if={can_transition?(@review.status, "approved")}
              id="approve-review-button"
              type="button"
              phx-click="approve"
              phx-value-id={@review.id}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-check" class="size-4" /> Approve
            </button>
            <button
              :if={can_transition?(@review.status, "rejected")}
              id="reject-review-button"
              type="button"
              phx-click="reject"
              phx-value-id={@review.id}
              class="btn btn-error btn-sm"
            >
              <.icon name="hero-x-mark" class="size-4" /> Reject
            </button>
            <button
              :if={can_transition?(@review.status, "manual_review")}
              id="manual-review-button"
              type="button"
              phx-click="request_manual_review"
              phx-value-id={@review.id}
              class="btn btn-warning btn-sm"
            >
              <.icon name="hero-magnifying-glass" class="size-4" /> Manual review
            </button>
          </div>
        </div>
      </div>

      <.link
        navigate={~p"/admin/compliance_reviews"}
        class="btn btn-ghost btn-sm"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to reviews
      </.link>
    </div>
    """
  end

  attr :transfer, :map, required: true

  defp transfer_summary(assigns) do
    ~H"""
    <dl class="mt-2 grid gap-4 text-sm sm:grid-cols-2">
      <.detail_row label="Originator" value={@transfer.originator_party.legal_name} />
      <.detail_row label="Counterparty" value={@transfer.counterparty_party.legal_name} />
      <.detail_row
        label="Originator amount"
        value={
          format_currency_amount(
            @transfer.amount_in_originator_currency,
            @transfer.originator_currency_code
          )
        }
      />
      <.detail_row
        label="Counterparty amount"
        value={
          format_currency_amount(
            @transfer.amount_in_counterparty_currency,
            @transfer.counterparty_currency_code
          )
        }
      />
      <.detail_row label="Transfer status" value={render_status(@transfer.status)} />
      <.detail_row
        label="Created"
        value={Calendar.strftime(@transfer.inserted_at, "%B %-d, %Y %-I:%M %p")}
      />
    </dl>
    """
  end

  attr :party, :map, required: true

  defp party_summary(assigns) do
    ~H"""
    <dl class="mt-2 grid gap-4 text-sm sm:grid-cols-2">
      <.detail_row label="Legal name" value={@party.legal_name} />
      <.detail_row label="Country" value={@party.country_code || "-"} />
      <.detail_row label="Tax ID" value={@party.tax_id || "-"} />
      <.detail_row
        label="Onboarded"
        value={Calendar.strftime(@party.inserted_at, "%B %-d, %Y %-I:%M %p")}
      />
    </dl>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp detail_row(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
        {@label}
      </dt>
      <dd class="mt-1 text-sm font-medium">{@value}</dd>
    </div>
    """
  end

  defp apply_action(socket, :index, params) do
    filter_key = Map.get(params, "filter", "pending")
    filter = Enum.find(@status_filters, &(&1.key == filter_key)) || List.first(@status_filters)
    reviews = list_reviews_for_filter(filter)

    socket
    |> assign(:page_title, "Compliance reviews")
    |> assign(:active_filter, filter.key)
    |> assign(:reviews_empty?, reviews == [])
    |> stream(:reviews, reviews, reset: true)
    |> assign(:review_notes_value, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    review = Compliance.get_review!(id)
    notes_form = to_form(%{"notes" => review.notes || ""}, as: :review_notes)

    socket
    |> assign(:page_title, "Compliance review")
    |> assign(:review, review)
    |> assign(:notes_form, notes_form)
    |> assign(:review_notes_value, review.notes)
  end

  defp list_reviews_for_filter(%{statuses: nil}) do
    Compliance.list_reviews()
    |> Enum.map(&decorate_review/1)
  end

  defp list_reviews_for_filter(%{statuses: statuses}) do
    statuses
    |> Enum.flat_map(&Compliance.list_reviews_by_status/1)
    |> Enum.map(&decorate_review/1)
  end

  defp decorate_review(review) do
    %{
      id: review.id,
      status: review.status,
      subject_type: subject_type(review),
      subject_label: subject_label(review),
      reviewer_name: reviewer_label(review.reviewed_by_user),
      submitted_at: review.inserted_at
    }
  end

  defp subject_type(%Review{transfer_id: nil, party_id: nil}), do: "-"
  defp subject_type(%Review{transfer_id: id}) when not is_nil(id), do: "Transfer"
  defp subject_type(_review), do: "Party"

  defp subject_label(%Review{transfer: %{} = transfer}), do: transfer.id
  defp subject_label(%Review{party: %{} = party}), do: party.legal_name
  defp subject_label(_review), do: "-"

  defp subject_reference(%Review{transfer: transfer}) when not is_nil(transfer), do: transfer.id
  defp subject_reference(%Review{party: party}) when not is_nil(party), do: party.id
  defp subject_reference(_review), do: "-"

  defp reviewer_label(%{email: email}), do: email
  defp reviewer_label(_reviewer), do: "Pending"

  defp render_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp can_transition?(status, target) do
    target in Compliance.allowed_targets(status)
  end

  defp status_badge_classes("created"), do: "badge badge-soft badge-warning"
  defp status_badge_classes("manual_review"), do: "badge badge-soft badge-warning"
  defp status_badge_classes("approved"), do: "badge badge-soft badge-success"
  defp status_badge_classes("rejected"), do: "badge badge-soft badge-error"
  defp status_badge_classes(_status), do: "badge badge-soft"

  defp notify_party_decision(%Review{party: %{created_by_user_id: nil}}, _decision), do: :ok

  defp notify_party_decision(%Review{party: party}, decision) do
    case decision do
      :approved ->
        Notifications.notify_party_approved(party, party.created_by_user_id)

      :rejected ->
        Notifications.notify_party_rejected(party, party.created_by_user_id)

      :manual_review ->
        Notifications.notify_party_in_manual_review(party, party.created_by_user_id)
    end
  end
end
