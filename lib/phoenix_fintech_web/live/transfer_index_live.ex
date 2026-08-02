defmodule PhoenixFintechWeb.TransferIndexLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()

    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Transfers")
      |> assign(:transfers, list_transfers_for_current_user(current_user))
      |> assign(:templates, list_templates_for_current_user(current_user))
      |> assign(:transfer_template_source, nil)
      |> assign(:pending_template, nil)
      |> assign(:pending_amount, nil)
      |> assign(:template_step, :amount)
      |> assign(:transfer_template_creation_error, nil)
      |> assign(:template_error, nil)
      |> assign(:transfer_template_creation_form, transfer_template_creation_form())
      |> assign(:template_transfer_form, template_transfer_form(current_user))

    {:ok, socket}
  end

  @impl true
  def handle_event("open_transfer_template_creation", %{"id" => id}, socket) do
    transfer = Enum.find(socket.assigns.transfers, &(&1.id == id and &1.status == "completed"))

    if transfer && transfer.transfer_quote do
      {:noreply,
       socket
       |> assign(:transfer_template_source, transfer)
       |> assign(:transfer_template_creation_form, transfer_template_creation_form())
       |> assign(:transfer_template_creation_error, nil)
       |> push_event("open_dialog", %{id: "transfer-template-creation-dialog"})}
    else
      {:noreply,
       put_flash(socket, :error, "Only completed quoted transfers can be used as templates.")}
    end
  end

  def handle_event("close_transfer_template_creation", _params, socket) do
    {:noreply,
     socket
     |> assign(:transfer_template_source, nil)
     |> assign(:transfer_template_creation_error, nil)}
  end

  def handle_event("save_template", %{"template" => params}, socket) do
    spread = selected_spread(params, socket.assigns.transfer_template_source)

    case spread do
      {:ok, spread_basis_points} ->
        case Transfers.create_transfer_template(
               socket.assigns.current_user.id,
               socket.assigns.transfer_template_source.id,
               spread_basis_points
             ) do
          {:ok, _template} ->
            templates = Transfers.list_transfer_templates_for_user(socket.assigns.current_user.id)

            {:noreply,
             socket
             |> assign(:templates, templates)
             |> assign(:template_transfer_form, template_transfer_form(templates))
             |> assign(:transfer_template_source, nil)
             |> push_event("close_dialog", %{id: "transfer-template-creation-dialog"})
             |> put_flash(:info, "Transfer template created.")}

          {:error, :invalid_source_transfer} ->
            {:noreply,
             assign(
               socket,
               :transfer_template_creation_error,
               "This transfer can no longer be used as a template."
             )}

          {:error, changeset} ->
            {:noreply,
             assign(socket, :transfer_template_creation_error, changeset_error(changeset))}
        end

      {:error, message} ->
        {:noreply,
         socket
         |> assign(:transfer_template_creation_form, to_form(params, as: :template))
         |> assign(:transfer_template_creation_error, message)}
    end
  end

  def handle_event("open_template_transfer", _params, socket) do
    {:noreply,
     socket
     |> assign(:template_step, :amount)
     |> assign(:pending_template, nil)
     |> assign(:pending_amount, nil)
     |> assign(:template_error, nil)
     |> assign(:template_transfer_form, template_transfer_form(socket.assigns.templates))
     |> push_event("open_dialog", %{id: "create-from-template-dialog"})}
  end

  def handle_event("close_template_transfer", _params, socket) do
    {:noreply,
     socket
     |> assign(:template_step, :amount)
     |> assign(:pending_template, nil)
     |> assign(:pending_amount, nil)
     |> assign(:template_error, nil)}
  end

  def handle_event("review_template_transfer", %{"transfer" => params}, socket) do
    template =
      Transfers.get_transfer_template_for_user(
        socket.assigns.current_user.id,
        Map.get(params, "template_id")
      )

    case {template, parse_positive_amount(Map.get(params, "amount"))} do
      {nil, _} ->
        {:noreply, template_form_error(socket, params, "Choose a transfer template.")}

      {_, {:error, message}} ->
        {:noreply, template_form_error(socket, params, message)}

      {template, {:ok, amount}} ->
        {:noreply,
         socket
         |> assign(:pending_template, template)
         |> assign(:pending_amount, amount)
         |> assign(:template_step, :summary)
         |> assign(:template_error, nil)}
    end
  end

  def handle_event("back_to_template_amount", _params, socket) do
    {:noreply,
     socket
     |> assign(:template_step, :amount)
     |> assign(:template_error, nil)}
  end

  def handle_event("confirm_template_transfer", _params, socket) do
    case Transfers.create_transfer_from_template(
           socket.assigns.current_user.id,
           socket.assigns.pending_template.id,
           socket.assigns.pending_amount
         ) do
      {:ok, transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer created and submitted for review.")
         |> push_navigate(to: ~p"/app/transfers/#{transfer.id}")}

      {:error, _step, reason, _changes} ->
        {:noreply, assign(socket, :template_error, transfer_error(reason))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      socket={@socket}
    >
      <section id="transfers-index" class="mx-auto max-w-6xl">
        <div class="mb-6 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-semibold">Transfers</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Cross-border movement requests by party.
            </p>
          </div>
          <div class="flex flex-wrap justify-end gap-2">
            <button
              id="create-from-template-button"
              type="button"
              phx-click="open_template_transfer"
              class="btn btn-outline"
            >
              <.icon name="hero-document-duplicate" class="size-4" /> Create from template
            </button>
            <.button navigate={~p"/app/transfers/new"} variant="primary" id="new-transfer-link">
              <.icon name="hero-arrows-right-left" class="size-4" /> Create new transfer
            </.button>
          </div>
        </div>

        <div class="card card-border bg-base-100">
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Direction</th>
                  <th>Originator name</th>
                  <th>Counterparty name</th>
                  <th>Status</th>
                  <th><span class="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody id="transfers-table">
                <tr :if={@transfers == []}>
                  <td colspan="6" class="py-8 text-center text-base-content/60">No transfers yet.</td>
                </tr>
                <tr
                  :for={transfer <- @transfers}
                  id={"transfer-#{transfer.id}"}
                  phx-click={JS.navigate(~p"/app/transfers/#{transfer.id}")}
                  class="hover cursor-pointer"
                >
                  <td>
                    <.copy_value id={"transfer-#{transfer.id}-copy"} value={transfer.id} />
                  </td>
                  <td>
                    <span class="badge badge-soft">
                      <.icon
                        name={
                          if transfer.direction == :send, do: "hero-arrow-up", else: "hero-arrow-down"
                        }
                        class="size-4"
                      />
                      {transfer.direction |> to_string() |> String.capitalize()}
                    </span>
                  </td>
                  <td>
                    {transfer.originator_party.legal_name}
                  </td>
                  <td>
                    {transfer.counterparty_party.legal_name}
                  </td>
                  <td><span class="badge badge-ghost">{humanize(transfer.status)}</span></td>
                  <td class="text-right">
                    <button
                      :if={transfer.status == "completed" && transfer.transfer_quote}
                      id={"transfer-actions-button-#{transfer.id}"}
                      type="button"
                      phx-hook=".StopRowClick"
                      popovertarget={"transfer-actions-#{transfer.id}"}
                      style={"anchor-name: --transfer-actions-#{transfer.id}"}
                      class="btn btn-ghost btn-sm btn-square"
                      aria-label="Transfer actions"
                    >
                      <.icon name="hero-ellipsis-vertical" class="size-5" />
                    </button>
                    <ul
                      :if={transfer.status == "completed" && transfer.transfer_quote}
                      id={"transfer-actions-#{transfer.id}"}
                      popover
                      style={"position-anchor: --transfer-actions-#{transfer.id}"}
                      class="dropdown dropdown-end menu z-10 w-48 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
                    >
                      <li>
                        <button
                          id={"create-template-#{transfer.id}"}
                          type="button"
                          phx-click="open_transfer_template_creation"
                          phx-value-id={transfer.id}
                        >
                          <.icon name="hero-document-duplicate" class="size-4" /> Create template
                        </button>
                      </li>
                    </ul>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <dialog
          id="transfer-template-creation-dialog"
          class="modal"
          phx-hook=".LiveDialog"
          data-close-event="close_transfer_template_creation"
        >
          <div class="modal-box relative max-w-lg">
            <button
              id="close-transfer-template-creation-dialog"
              type="button"
              phx-click={JS.dispatch("phx:close-dialog", to: "#transfer-template-creation-dialog")}
              class="btn btn-circle btn-ghost btn-sm absolute top-4 right-4"
              aria-label="Close dialog"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
            <%= if @transfer_template_source do %>
              <h2 class="text-lg font-semibold">Create transfer template</h2>
              <p class="mt-1 text-sm text-base-content/70">
                Save the parties, currencies, direction, and spread. Transfer amounts are never saved.
              </p>

              <dl class="mt-4 grid grid-cols-2 gap-3 rounded-box bg-base-200 p-4 text-sm">
                <div>
                  <dt class="text-base-content/60">Originator</dt>
                  <dd class="font-medium">{@transfer_template_source.originator_party.legal_name}</dd>
                </div>
                <div>
                  <dt class="text-base-content/60">Counterparty</dt>
                  <dd class="font-medium">
                    {@transfer_template_source.counterparty_party.legal_name}
                  </dd>
                </div>
                <div>
                  <dt class="text-base-content/60">Currencies</dt>
                  <dd class="font-medium">
                    {@transfer_template_source.originator_currency_code} to {@transfer_template_source.counterparty_currency_code}
                  </dd>
                </div>
                <div>
                  <dt class="text-base-content/60">Direction</dt>
                  <dd class="font-medium">{humanize(@transfer_template_source.direction)}</dd>
                </div>
              </dl>

              <.form
                for={@transfer_template_creation_form}
                id="transfer-template-creation-form"
                phx-submit="save_template"
                class="group mt-4 space-y-3"
              >
                <fieldset class="fieldset">
                  <legend class="fieldset-legend">Template spread</legend>
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      id="template-spread-same"
                      type="radio"
                      name="template[spread_option]"
                      value="same"
                      class="radio radio-sm"
                      checked={@transfer_template_creation_form[:spread_option].value == "same"}
                    /> Same spread: {@transfer_template_source.transfer_quote.spread_basis_points} bps
                  </label>
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      id="template-spread-new"
                      type="radio"
                      name="template[spread_option]"
                      value="new"
                      class="radio radio-sm"
                      checked={@transfer_template_creation_form[:spread_option].value == "new"}
                    /> Use a new spread
                  </label>
                </fieldset>
                <div class="hidden group-has-[#template-spread-new:checked]:block">
                  <.input
                    field={@transfer_template_creation_form[:spread_basis_points]}
                    type="number"
                    label="New spread (basis points)"
                    min="0"
                    max="9999"
                    step="1"
                    placeholder="For example, 125"
                  />
                </div>
                <div
                  :if={@transfer_template_creation_error}
                  role="alert"
                  class="alert alert-error alert-soft text-sm"
                >
                  {@transfer_template_creation_error}
                </div>
                <div class="modal-action">
                  <button
                    type="button"
                    phx-click={
                      JS.dispatch("phx:close-dialog", to: "#transfer-template-creation-dialog")
                    }
                    class="btn btn-ghost"
                  >
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary">Save template</button>
                </div>
              </.form>
            <% end %>
          </div>
          <button
            type="button"
            phx-click={JS.dispatch("phx:close-dialog", to: "#transfer-template-creation-dialog")}
            class="modal-backdrop"
            aria-label="Close dialog"
          >
            close
          </button>
        </dialog>

        <dialog
          id="create-from-template-dialog"
          class="modal"
          phx-hook=".LiveDialog"
          data-close-event="close_template_transfer"
        >
          <div class="modal-box relative h-[30rem] max-h-[calc(100dvh-2rem)] max-w-lg overflow-hidden p-0">
            <button
              id="close-create-from-template-dialog"
              type="button"
              phx-click={JS.dispatch("phx:close-dialog", to: "#create-from-template-dialog")}
              class="btn btn-circle btn-ghost btn-sm absolute top-4 right-4 z-10"
              aria-label="Close dialog"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
            <%= if @templates == [] do %>
              <div class="flex h-full flex-col p-6">
                <h2 class="text-lg font-semibold">No transfer templates yet</h2>
                <p class="mt-2 text-sm text-base-content/70">
                  Complete a transfer, then use its Create template action to save your first template.
                </p>
                <div class="modal-action mt-auto">
                  <button
                    type="button"
                    phx-click={JS.dispatch("phx:close-dialog", to: "#create-from-template-dialog")}
                    class="btn"
                  >
                    Close
                  </button>
                </div>
              </div>
            <% else %>
              <div
                id="template-dialog-track"
                class={[
                  "flex h-full w-[200%] transition-transform duration-300 ease-out motion-reduce:transition-none",
                  @template_step == :summary && "-translate-x-1/2"
                ]}
              >
                <section
                  class="flex h-full w-1/2 shrink-0 flex-col p-6"
                  aria-hidden={@template_step != :amount}
                  inert={@template_step != :amount}
                >
                  <h2 class="text-lg font-semibold">Create from template</h2>
                  <p class="mt-1 text-sm text-base-content/70">
                    Choose a saved route and enter the new originator amount.
                  </p>
                  <.form
                    for={@template_transfer_form}
                    id="template-transfer-form"
                    phx-submit="review_template_transfer"
                    class="mt-4 flex flex-1 flex-col"
                  >
                    <.input
                      field={@template_transfer_form[:template_id]}
                      type="select"
                      label="Transfer template"
                      options={template_options(@templates)}
                      prompt="Choose a template"
                    />
                    <.input
                      field={@template_transfer_form[:amount]}
                      type="number"
                      label="Amount"
                      min="0.01"
                      step="0.01"
                      placeholder="0.00"
                    />
                    <div
                      :if={@template_error}
                      role="alert"
                      class="alert alert-error alert-soft mt-3 text-sm"
                    >
                      {@template_error}
                    </div>
                    <div class="modal-action mt-auto">
                      <button
                        type="button"
                        phx-click={
                          JS.dispatch(
                            "phx:close-dialog",
                            to: "#create-from-template-dialog"
                          )
                        }
                        class="btn btn-ghost"
                      >
                        Cancel
                      </button>
                      <button type="submit" class="btn btn-primary">See summary</button>
                    </div>
                  </.form>
                </section>

                <section
                  class="flex h-full w-1/2 shrink-0 flex-col p-6"
                  aria-hidden={@template_step != :summary}
                  inert={@template_step != :summary}
                >
                  <%= if @pending_template do %>
                    <h2 class="text-lg font-semibold">Transfer summary</h2>
                    <p class="mt-1 text-sm text-base-content/70">
                      A fresh quote will be locked and the transfer will be submitted for review.
                    </p>
                    <dl class="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 rounded-box bg-base-200 p-4 text-sm">
                      <div>
                        <dt class="text-base-content/60">Originator</dt>
                        <dd class="font-medium">{@pending_template.originator_party.legal_name}</dd>
                      </div>
                      <div>
                        <dt class="text-base-content/60">Counterparty</dt>
                        <dd class="font-medium">{@pending_template.counterparty_party.legal_name}</dd>
                      </div>
                      <div>
                        <dt class="text-base-content/60">Amount</dt>
                        <dd class="font-medium">
                          {format_currency_amount(
                            @pending_amount,
                            @pending_template.originator_currency_code
                          )}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-base-content/60">Direction</dt>
                        <dd class="font-medium">{humanize(@pending_template.direction)}</dd>
                      </div>
                      <div>
                        <dt class="text-base-content/60">Currencies</dt>
                        <dd class="font-medium">
                          {@pending_template.originator_currency_code} to {@pending_template.counterparty_currency_code}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-base-content/60">Spread</dt>
                        <dd class="font-medium">
                          {@pending_template.spread_basis_points} bps
                        </dd>
                      </div>
                    </dl>
                    <div
                      :if={@template_error}
                      role="alert"
                      class="alert alert-error alert-soft mt-4 text-sm"
                    >
                      {@template_error}
                    </div>
                    <div class="modal-action mt-auto">
                      <button
                        id="template-transfer-back"
                        type="button"
                        phx-click="back_to_template_amount"
                        class="btn btn-ghost"
                      >
                        Back
                      </button>
                      <button
                        id="template-transfer-confirm"
                        type="button"
                        phx-click="confirm_template_transfer"
                        class="btn btn-primary"
                      >
                        Submit for review
                      </button>
                    </div>
                  <% end %>
                </section>
              </div>
            <% end %>
          </div>
          <button
            type="button"
            phx-click={JS.dispatch("phx:close-dialog", to: "#create-from-template-dialog")}
            class="modal-backdrop"
            aria-label="Close dialog"
          >
            close
          </button>
        </dialog>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".LiveDialog">
          export default {
            mounted() {
              this.handleEvent("open_dialog", ({id}) => {
                if (id === this.el.id && !this.el.open) this.el.showModal()
              })
              this.handleEvent("close_dialog", ({id}) => {
                if (id === this.el.id && this.el.open) this.el.close()
              })
              this.el.addEventListener("phx:close-dialog", () => {
                if (this.el.open) this.el.close()
              })
              this.el.addEventListener("close", () => this.pushEvent(this.el.dataset.closeEvent, {}))
            },
            beforeUpdate() {
              this.wasOpen = this.el.open
              this.focusedElementId = this.el.contains(document.activeElement)
                ? document.activeElement.id
                : null
            },
            updated() {
              if (this.wasOpen && !this.el.open) this.el.showModal()

              const focusedElement = document.getElementById(this.focusedElementId)
              if (focusedElement && this.el.contains(focusedElement)) {
                focusedElement.focus({preventScroll: true})
              }
            }
          }
        </script>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".StopRowClick">
          export default {
            mounted() {
              this.el.addEventListener("click", event => event.stopPropagation())
            }
          }
        </script>
      </section>
    </Layouts.app>
    """
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))

  defp list_transfers_for_current_user(%{id: user_id}),
    do: Transfers.list_transfers_for_user(user_id)

  defp list_transfers_for_current_user(_), do: []

  defp list_templates_for_current_user(%{id: user_id}),
    do: Transfers.list_transfer_templates_for_user(user_id)

  defp list_templates_for_current_user(_), do: []

  defp transfer_template_creation_form do
    to_form(%{"spread_option" => "same", "spread_basis_points" => ""}, as: :template)
  end

  defp template_transfer_form(%{id: user_id}) do
    user_id |> Transfers.list_transfer_templates_for_user() |> template_transfer_form()
  end

  defp template_transfer_form([template | _]) do
    to_form(%{"template_id" => template.id, "amount" => ""}, as: :transfer)
  end

  defp template_transfer_form([]),
    do: to_form(%{"template_id" => "", "amount" => ""}, as: :transfer)

  defp template_transfer_form(_), do: template_transfer_form([])

  defp selected_spread(%{"spread_option" => "same"}, transfer),
    do: {:ok, transfer.transfer_quote.spread_basis_points}

  defp selected_spread(%{"spread_option" => "new", "spread_basis_points" => value}, _transfer) do
    case Integer.parse(value) do
      {spread, ""} when spread >= 0 and spread < 10_000 -> {:ok, spread}
      _ -> {:error, "Spread must be an integer from 0 to 9,999 basis points."}
    end
  end

  defp selected_spread(_, _transfer), do: {:error, "Choose a spread option."}

  defp parse_positive_amount(value) when value in [nil, ""], do: {:error, "Enter an amount."}

  defp parse_positive_amount(value) do
    case Decimal.parse(value) do
      {amount, ""} ->
        if Decimal.compare(amount, 0) == :gt,
          do: {:ok, amount},
          else: {:error, "Amount must be greater than zero."}

      _ ->
        {:error, "Enter a valid amount."}
    end
  end

  defp template_form_error(socket, params, message) do
    socket
    |> assign(:template_transfer_form, to_form(params, as: :transfer))
    |> assign(:template_error, message)
  end

  defp template_options(templates) do
    Enum.map(templates, fn template ->
      label =
        "#{template.originator_party.legal_name} to #{template.counterparty_party.legal_name} · " <>
          "#{template.originator_currency_code}/#{template.counterparty_currency_code} · " <>
          "#{template.spread_basis_points} bps"

      {label, template.id}
    end)
  end

  defp changeset_error(changeset) do
    case changeset.errors do
      [{_field, {message, _options}} | _] -> "Unable to create template: #{message}"
      _ -> "Unable to create transfer template."
    end
  end

  defp transfer_error(:missing_fx_rate), do: "A quote is not available for this currency pair."
  defp transfer_error(_reason), do: "Unable to create the transfer. Please try again."

  defp humanize(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
