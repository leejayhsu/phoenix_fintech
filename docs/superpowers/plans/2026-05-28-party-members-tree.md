# Party Members Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show party members as a hierarchy and move member creation into a reusable modal for top-level and child members.

**Architecture:** Keep the change inside `PhoenixFintechWeb.PartyShowLive`. Maintain a regular `:members` assign for tree rendering and parent option generation, while using LiveView events to open, close, and submit the modal. Use a recursive function component to render nested member nodes.

**Tech Stack:** Phoenix LiveView, HEEx, Tailwind CSS, Phoenix.LiveViewTest, LazyHTML selectors through `has_element?/2`.

---

### Task 1: Modal State and Opening Tests

**Files:**
- Modify: `test/phoenix_fintech_web/live/party_show_live_test.exs`
- Modify: `lib/phoenix_fintech_web/live/party_show_live.ex`

- [ ] **Step 1: Write failing tests for opening the modal**

Add tests that assert the top-level button opens the modal with the empty parent selected, and the child button opens it with an existing member selected:

```elixir
test "opens member modal for top-level and child members", %{conn: conn} do
  user = user_fixture()
  conn = log_in_conn(conn, user)
  party = party_fixture()

  {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

  view |> element("#add-top-level-member-button") |> render_click()

  assert has_element?(view, "#party-member-modal")
  assert has_element?(view, "#party-member-form")
  assert has_element?(view, "#party_member_parent_party_member_id option[selected][value='']")

  representative = List.first(Parties.get_party_with_details!(party.id).members)

  view |> element("#add-child-member-#{representative.id}") |> render_click()

  assert has_element?(
           view,
           "#party_member_parent_party_member_id option[selected][value='#{representative.id}']"
         )
end
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `mix test test/phoenix_fintech_web/live/party_show_live_test.exs`

Expected: FAIL because `#add-top-level-member-button` and modal elements do not exist yet.

- [ ] **Step 3: Add minimal modal state and open/close events**

In `mount/3`, assign:

```elixir
|> assign(:members, party.members)
|> assign(:member_modal_open?, false)
|> assign(:member_modal_title, "Add member")
```

Add event handlers:

```elixir
def handle_event("open_member_modal", %{"parent-id" => parent_id}, socket) do
  title = if parent_id == "", do: "Add top-level member", else: "Add child member"

  {:noreply,
   socket
   |> assign(:member_modal_open?, true)
   |> assign(:member_modal_title, title)
   |> assign_member_form(%{"parent_party_member_id" => parent_id})}
end

def handle_event("close_member_modal", _params, socket) do
  {:noreply,
   socket
   |> assign(:member_modal_open?, false)
   |> assign_member_form()}
end
```

Update `assign_member_form/1` to accept optional overrides:

```elixir
defp assign_member_form(socket, overrides \\ %{}) do
  member_attrs =
    Map.merge(
      %{
        "type" => "individual",
        "country_code" => "US",
        "parent_party_member_id" => ""
      },
      overrides
    )

  changeset =
    Parties.change_party_member(%PartyMember{party_id: socket.assigns.party.id}, member_attrs)

  assign(socket, :member_form, to_form(changeset, as: :party_member))
end
```

- [ ] **Step 4: Add minimal modal markup**

Replace the inline member form with a button:

```heex
<.button
  id="add-top-level-member-button"
  type="button"
  phx-click="open_member_modal"
  phx-value-parent-id=""
>
  Add top-level member
</.button>
```

Render the modal when open:

```heex
<div :if={@member_modal_open?} id="party-member-modal" class="fixed inset-0 z-50">
  <button
    id="party-member-modal-backdrop"
    type="button"
    phx-click="close_member_modal"
    class="absolute inset-0 bg-zinc-950/40"
    aria-label="Close member form"
  >
  </button>
  <div class="absolute left-1/2 top-1/2 w-[min(92vw,34rem)] -translate-x-1/2 -translate-y-1/2 rounded-lg bg-white p-5 shadow-xl dark:bg-zinc-900">
    <div class="mb-4 flex items-center justify-between gap-4">
      <h3 class="text-lg font-semibold">{@member_modal_title}</h3>
      <button id="close-member-modal-button" type="button" phx-click="close_member_modal">Close</button>
    </div>
    <.form for={@member_form} id="party-member-form" phx-submit="create_member" class="grid gap-3">
      <.input field={@member_form[:legal_name]} label="Legal name" />
      <.input field={@member_form[:type]} type="select" label="Type" options={[{"Individual", "individual"}, {"Business", "business"}]} />
      <.input field={@member_form[:parent_party_member_id]} type="select" label="Parent member" options={@member_parent_options} />
      <.input field={@member_form[:title]} label="Title" />
      <.input field={@member_form[:address_line1]} label="Address line 1" />
      <.input field={@member_form[:locality]} label="City" />
      <.input field={@member_form[:region]} label="Region" />
      <.input field={@member_form[:postal_code]} label="Postal code" />
      <.input field={@member_form[:country_code]} label="Country code" />
      <.button id="create-member-button" type="submit">Add member</.button>
    </.form>
  </div>
</div>
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `mix test test/phoenix_fintech_web/live/party_show_live_test.exs`

Expected: PASS for the modal opening test.

### Task 2: Tree Rendering and Creation Flow

**Files:**
- Modify: `test/phoenix_fintech_web/live/party_show_live_test.exs`
- Modify: `lib/phoenix_fintech_web/live/party_show_live.ex`

- [ ] **Step 1: Write failing test for child rendering under parent**

Add a test that opens the child modal, submits a child member, and verifies a nested node appears under the parent:

```elixir
test "creates and renders a child member under its parent", %{conn: conn} do
  user = user_fixture()
  conn = log_in_conn(conn, user)
  party = party_fixture()
  representative = List.first(Parties.get_party_with_details!(party.id).members)

  {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

  view |> element("#add-child-member-#{representative.id}") |> render_click()

  view
  |> form("#party-member-form",
    party_member: %{
      parent_party_member_id: representative.id,
      legal_name: "Child Holding LLC",
      type: "business",
      title: "Subsidiary",
      address_line1: "200 Market",
      locality: "Austin",
      region: "TX",
      postal_code: "78701",
      country_code: "US"
    }
  )
  |> render_submit()

  assert has_element?(view, "#member-children-#{representative.id} #member-node", "Child Holding LLC")
  refute has_element?(view, "#party-member-modal")
end
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `mix test test/phoenix_fintech_web/live/party_show_live_test.exs`

Expected: FAIL because nested tree rendering is not implemented.

- [ ] **Step 3: Refresh member assigns after mutations**

Update successful member creation to refresh members, close modal, and reset the form:

```elixir
{:ok, member} ->
  members = [member | socket.assigns.members]

  {:noreply,
   socket
   |> assign(:members, members)
   |> assign(:member_parent_options, member_parent_options(members))
   |> assign(:member_modal_open?, false)
   |> assign_member_form()}
```

Update delete and role toggle to keep `:members` in sync:

```elixir
members = Enum.reject(socket.assigns.members, &(&1.id == member.id))
```

For role toggle:

```elixir
members =
  Enum.map(socket.assigns.members, fn existing ->
    if existing.id == member.id, do: member, else: existing
  end)

{:noreply, assign(socket, :members, members)}
```

- [ ] **Step 4: Render a recursive tree**

Add a function component:

```elixir
attr :members, :list, required: true
attr :children_by_parent, :map, required: true
attr :depth, :integer, default: 0

defp member_tree(assigns) do
  ~H"""
  <div class={["space-y-3", @depth > 0 && "mt-3 border-l border-zinc-200 pl-4 dark:border-zinc-700"]}>
    <div :for={member <- @members} id="member-node" class="rounded-lg border border-zinc-200 bg-white p-3 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="font-medium">{member.legal_name || "Unnamed member"}</p>
          <p class="text-xs text-zinc-600 dark:text-zinc-400">{member.type} · {member.title || "-"}</p>
        </div>
        <button id={"add-child-member-#{member.id}"} type="button" phx-click="open_member_modal" phx-value-parent-id={member.id} class="rounded-md border px-2 py-1 text-xs">+</button>
      </div>
      <div class="mt-2 flex flex-wrap gap-2">
        <button phx-click="toggle_role" phx-value-id={member.id} phx-value-role="legal_rep" class="rounded-md border px-2 py-1 text-xs">Legal rep: {member.is_legal_rep}</button>
        <button phx-click="toggle_role" phx-value-id={member.id} phx-value-role="ubo" class="rounded-md border px-2 py-1 text-xs">Beneficiary: {member.is_ubo}</button>
        <button phx-click="delete_member" phx-value-id={member.id} class="rounded-md border border-red-300 px-2 py-1 text-xs text-red-700">Delete</button>
      </div>
      <div id={"member-children-#{member.id}"}>
        <.member_tree members={Map.get(@children_by_parent, member.id, [])} children_by_parent={@children_by_parent} depth={@depth + 1} />
      </div>
    </div>
  </div>
  """
end
```

Replace the stream container:

```heex
<div id="members" class="mt-4">
  <div :if={@members == []} class="rounded-lg border border-dashed p-4 text-sm text-zinc-500">
    No party members yet.
  </div>
  <.member_tree
    members={Map.get(build_member_children(@members), nil, [])}
    children_by_parent={build_member_children(@members)}
  />
</div>
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `mix test test/phoenix_fintech_web/live/party_show_live_test.exs`

Expected: PASS for tree rendering and modal behavior.

### Task 3: Full Verification

**Files:**
- Modify: `lib/phoenix_fintech_web/live/party_show_live.ex`
- Modify: `test/phoenix_fintech_web/live/party_show_live_test.exs`

- [ ] **Step 1: Run focused LiveView tests**

Run: `mix test test/phoenix_fintech_web/live/party_show_live_test.exs`

Expected: all tests pass.

- [ ] **Step 2: Run project precommit**

Run: `mix precommit`

Expected: all checks pass without warnings or formatting changes left unstaged.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add lib/phoenix_fintech_web/live/party_show_live.ex test/phoenix_fintech_web/live/party_show_live_test.exs docs/superpowers/plans/2026-05-28-party-members-tree.md
git commit -m "feat: show party members as tree"
```
