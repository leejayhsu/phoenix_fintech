defmodule PhoenixFintechWeb.OriginatorOnboardingLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page_title, "New originator")
      |> assign_current_user()
      |> assign(:step, :party)
      |> assign(:party_params, default_party_params())
      |> assign(:party_government_id_params, default_government_id_params("ein"))
      |> assign(:representative_params, default_representative_params())
      |> assign(:representative_government_id_params, default_government_id_params("ssn"))
      |> assign_party_forms()
      |> assign_representative_forms()

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "save_party",
        %{"party" => party_params, "party_government_id" => government_id_params},
        socket
      ) do
    party_changeset = Parties.change_party(party_params)
    government_id_changeset = Parties.change_government_id(government_id_params)

    if party_changeset.valid? and government_id_changeset.valid? do
      {:noreply,
       socket
       |> assign(:step, :representative)
       |> assign(:party_params, party_params)
       |> assign(:party_government_id_params, government_id_params)
       |> assign_party_forms()}
    else
      {:noreply,
       socket
       |> assign(:party_params, party_params)
       |> assign(:party_government_id_params, government_id_params)
       |> assign_party_forms(:validate)}
    end
  end

  def handle_event(
        "save_representative",
        %{
          "representative" => representative_params,
          "representative_government_id" => government_id_params
        },
        socket
      ) do
    representative_changeset = Parties.change_representative(representative_params)
    government_id_changeset = Parties.change_government_id(government_id_params)

    if representative_changeset.valid? and government_id_changeset.valid? do
      {:noreply,
       socket
       |> assign(:step, :review)
       |> assign(:representative_params, representative_params)
       |> assign(:representative_government_id_params, government_id_params)
       |> assign_representative_forms()}
    else
      {:noreply,
       socket
       |> assign(:representative_params, representative_params)
       |> assign(:representative_government_id_params, government_id_params)
       |> assign_representative_forms(:validate)}
    end
  end

  def handle_event("back_to_party", _params, socket) do
    {:noreply, assign(socket, :step, :party)}
  end

  def handle_event("back_to_representative", _params, socket) do
    {:noreply, assign(socket, :step, :representative)}
  end

  def handle_event("create_originator", _params, socket) do
    attrs = %{
      "party" => socket.assigns.party_params,
      "party_government_id" => socket.assigns.party_government_id_params,
      "representative" => socket.assigns.representative_params,
      "representative_government_id" => socket.assigns.representative_government_id_params
    }

    case Parties.create_originator(attrs) do
      {:ok, _party} ->
        {:noreply,
         socket
         |> put_flash(:info, "Originator party created.")
         |> push_navigate(to: ~p"/app/parties")}

      {:error, :party, changeset, _changes} ->
        {:noreply,
         socket
         |> put_flash(:error, "Review the company details.")
         |> assign(:step, :party)
         |> assign(:party_form, to_form(%{changeset | action: :validate}))
         |> assign(
           :party_government_id_form,
           to_form(Parties.change_government_id(socket.assigns.party_government_id_params),
             as: :party_government_id
           )
         )}

      {:error, _step, _changeset, _changes} ->
        {:noreply,
         socket
         |> put_flash(:error, "Review the representative and government ID details.")
         |> assign(:step, :representative)
         |> assign_representative_forms(:validate)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="originator-onboarding" class="mx-auto max-w-5xl">
        <div class="mb-8 flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-emerald-700">
              Originator onboarding
            </p>
            <h1 class="mt-2 text-3xl font-semibold text-zinc-950 dark:text-white">
              Add a business party
            </h1>
            <p class="mt-3 max-w-2xl text-sm leading-6 text-zinc-600 dark:text-zinc-300">
              Capture the business identity, ownership representative, and tax identifiers needed before transfers can reference this originator.
            </p>
          </div>

          <div class="grid min-w-72 grid-cols-3 overflow-hidden rounded-lg border border-zinc-200 bg-white text-xs font-medium shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
            <.step_pill
              label="Business"
              active={@step == :party}
              complete={@step in [:representative, :review]}
            />
            <.step_pill
              label="Representative"
              active={@step == :representative}
              complete={@step == :review}
            />
            <.step_pill label="Review" active={@step == :review} complete={false} />
          </div>
        </div>

        <div class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-900 sm:p-8">
          <%= case @step do %>
            <% :party -> %>
              <.party_step party_form={@party_form} government_id_form={@party_government_id_form} />
            <% :representative -> %>
              <.representative_step
                representative_form={@representative_form}
                government_id_form={@representative_government_id_form}
              />
            <% :review -> %>
              <.review_step
                party_params={@party_params}
                party_government_id_params={@party_government_id_params}
                representative_params={@representative_params}
              />
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :complete, :boolean, required: true

  defp step_pill(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-center gap-2 px-3 py-3 transition",
      @active && "bg-zinc-950 text-white dark:bg-white dark:text-zinc-950",
      @complete && "bg-emerald-50 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200",
      !@active && !@complete && "text-zinc-500"
    ]}>
      <.icon :if={@complete} name="hero-check-circle" class="size-4" />
      <span>{@label}</span>
    </div>
    """
  end

  attr :party_form, :map, required: true
  attr :government_id_form, :map, required: true

  defp party_step(assigns) do
    ~H"""
    <.form for={@party_form} id="party-step-form" phx-submit="save_party">
      <div class="grid gap-5 lg:grid-cols-[1fr_18rem]">
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@party_form[:legal_name]}
            label="Legal business name"
            autocomplete="organization"
          />
          <.input field={@party_form[:tax_id]} label="Tax ID" />
          <.input
            field={@party_form[:address_line1]}
            label="Address line 1"
            autocomplete="address-line1"
          />
          <.input
            field={@party_form[:address_line2]}
            label="Address line 2"
            autocomplete="address-line2"
          />
          <.input field={@party_form[:locality]} label="City" autocomplete="address-level2" />
          <.input field={@party_form[:region]} label="Region" autocomplete="address-level1" />
          <.input field={@party_form[:postal_code]} label="Postal code" autocomplete="postal-code" />
          <.input
            field={@party_form[:country_code]}
            label="Country code"
            maxlength="2"
            autocomplete="country"
          />
        </div>

        <div class="rounded-lg bg-zinc-50 p-4 dark:bg-zinc-950">
          <h2 class="text-sm font-semibold text-zinc-950 dark:text-white">Business government ID</h2>
          <.input
            field={@government_id_form[:type]}
            type="select"
            label="Type"
            options={[EIN: "ein", Passport: "passport", "National ID": "national_id"]}
          />
          <.input field={@government_id_form[:country_code]} label="Issuing country" maxlength="2" />
          <.input field={@government_id_form[:value]} label="Value" />
        </div>
      </div>

      <div class="mt-8 flex justify-end">
        <.button variant="primary" type="submit" id="continue-to-representative-button">
          Continue <.icon name="hero-arrow-right" class="size-4" />
        </.button>
      </div>
    </.form>
    """
  end

  attr :representative_form, :map, required: true
  attr :government_id_form, :map, required: true

  defp representative_step(assigns) do
    ~H"""
    <.form for={@representative_form} id="representative-step-form" phx-submit="save_representative">
      <div class="grid gap-5 lg:grid-cols-[1fr_18rem]">
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@representative_form[:legal_name]}
            label="Full legal name"
            autocomplete="name"
          />
          <.input field={@representative_form[:title]} label="Title" />
          <.input
            field={@representative_form[:address_line1]}
            label="Address line 1"
            autocomplete="address-line1"
          />
          <.input
            field={@representative_form[:address_line2]}
            label="Address line 2"
            autocomplete="address-line2"
          />
          <.input field={@representative_form[:locality]} label="City" autocomplete="address-level2" />
          <.input field={@representative_form[:region]} label="Region" autocomplete="address-level1" />
          <.input
            field={@representative_form[:postal_code]}
            label="Postal code"
            autocomplete="postal-code"
          />
          <.input
            field={@representative_form[:country_code]}
            label="Country code"
            maxlength="2"
            autocomplete="country"
          />
        </div>

        <div class="rounded-lg bg-zinc-50 p-4 dark:bg-zinc-950">
          <h2 class="text-sm font-semibold text-zinc-950 dark:text-white">
            Representative government ID
          </h2>
          <.input
            field={@government_id_form[:type]}
            type="select"
            label="Type"
            options={[SSN: "ssn", Passport: "passport", "National ID": "national_id"]}
          />
          <.input field={@government_id_form[:country_code]} label="Issuing country" maxlength="2" />
          <.input field={@government_id_form[:value]} label="Value" />
        </div>
      </div>

      <div class="mt-8 flex items-center justify-between">
        <.button type="button" phx-click="back_to_party" id="back-to-party-button">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.button>
        <.button variant="primary" type="submit" id="continue-to-review-button">
          Review <.icon name="hero-arrow-right" class="size-4" />
        </.button>
      </div>
    </.form>
    """
  end

  attr :party_params, :map, required: true
  attr :party_government_id_params, :map, required: true
  attr :representative_params, :map, required: true

  defp review_step(assigns) do
    ~H"""
    <div id="originator-review" class="space-y-6">
      <div class="grid gap-4 md:grid-cols-2">
        <.review_panel title="Business">
          <:row label="Legal name">{@party_params["legal_name"]}</:row>
          <:row label="Tax ID">{@party_params["tax_id"]}</:row>
          <:row label="Location">
            {@party_params["locality"]}, {@party_params["region"]} {@party_params["postal_code"]}
          </:row>
          <:row label="Government ID">
            {String.upcase(@party_government_id_params["type"] || "")}
          </:row>
        </.review_panel>

        <.review_panel title="Representative">
          <:row label="Legal name">{@representative_params["legal_name"]}</:row>
          <:row label="Title">{@representative_params["title"]}</:row>
          <:row label="Location">
            {@representative_params["locality"]}, {@representative_params["region"]} {@representative_params[
              "postal_code"
            ]}
          </:row>
          <:row label="Role">Legal representative and UBO</:row>
        </.review_panel>
      </div>

      <div class="flex items-center justify-between">
        <.button type="button" phx-click="back_to_representative" id="back-to-representative-button">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.button>
        <.button
          variant="primary"
          type="button"
          id="create-originator-button"
          phx-click="create_originator"
        >
          <.icon name="hero-building-office-2" class="size-4" /> Create originator
        </.button>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true

  slot :row, required: true do
    attr :label, :string, required: true
  end

  defp review_panel(assigns) do
    ~H"""
    <section class="rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 class="mb-4 text-sm font-semibold text-zinc-950 dark:text-white">{@title}</h2>
      <dl class="space-y-3">
        <div :for={row <- @row}>
          <dt class="text-xs font-medium uppercase tracking-wide text-zinc-500">{row.label}</dt>
          <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100">{render_slot(row)}</dd>
        </div>
      </dl>
    </section>
    """
  end

  defp assign_party_forms(socket, action \\ nil) do
    party_changeset = %{Parties.change_party(socket.assigns.party_params) | action: action}

    government_id_changeset = %{
      Parties.change_government_id(socket.assigns.party_government_id_params)
      | action: action
    }

    socket
    |> assign(:party_form, to_form(party_changeset))
    |> assign(
      :party_government_id_form,
      to_form(government_id_changeset, as: :party_government_id)
    )
  end

  defp assign_representative_forms(socket, action \\ nil) do
    representative_changeset = %{
      Parties.change_representative(socket.assigns.representative_params)
      | action: action
    }

    government_id_changeset = %{
      Parties.change_government_id(socket.assigns.representative_government_id_params)
      | action: action
    }

    socket
    |> assign(:representative_form, to_form(representative_changeset, as: :representative))
    |> assign(
      :representative_government_id_form,
      to_form(government_id_changeset, as: :representative_government_id)
    )
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket) do
    assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
  end

  defp default_party_params do
    %{
      "legal_name" => "",
      "tax_id" => "",
      "address_line1" => "",
      "address_line2" => "",
      "locality" => "",
      "region" => "",
      "postal_code" => "",
      "country_code" => "US"
    }
  end

  defp default_representative_params do
    %{
      "legal_name" => "",
      "title" => "",
      "address_line1" => "",
      "address_line2" => "",
      "locality" => "",
      "region" => "",
      "postal_code" => "",
      "country_code" => "US"
    }
  end

  defp default_government_id_params(type) do
    %{"type" => type, "country_code" => "US", "value" => ""}
  end
end
