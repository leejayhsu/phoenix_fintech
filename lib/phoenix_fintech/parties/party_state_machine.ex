defmodule PhoenixFintech.Parties.PartyStateMachine do
  @moduledoc """
  Declares the party lifecycle state machine.

      created
         |
         v
      compliance_review <----+
         |  ^  |  ^          |
         v  |  v  |          |
   compliance_approved      |
         |  ^  |  ^          |
         v  |  v  |          |
   compliance_rejected      |
         |  ^  |  ^          |
         v  |  v  |          |
   compliance_flagged ------+

  States:

    * `created` - initial state, party has been onboarded but has not yet
      entered the compliance workflow
    * `compliance_review` - party is awaiting or undergoing compliance review
    * `compliance_approved` - party has been cleared by compliance
    * `compliance_rejected` - party has been denied; *not* terminal, may still
      be manually moved to `compliance_approved`
    * `compliance_flagged` - party has been flagged (e.g. by continuous
      monitoring); may be reached from any `compliance_*` state

  The `compliance_*` states flow freely between each other to support manual
  overrides and continuous monitoring. None of them are terminal.

  Transitions are declared as a map from each status to the set of statuses it
  may move to. `PhoenixFintech.Parties.allowed_targets/1` is the public API
  for inspecting valid targets.
  """

  @states [
    "created",
    "compliance_review",
    "compliance_approved",
    "compliance_rejected",
    "compliance_flagged"
  ]

  @transitions %{
    "created" => ["compliance_review"],
    "compliance_review" => [
      "compliance_approved",
      "compliance_rejected",
      "compliance_flagged"
    ],
    "compliance_approved" => [
      "compliance_review",
      "compliance_rejected",
      "compliance_flagged"
    ],
    "compliance_rejected" => [
      "compliance_review",
      "compliance_approved",
      "compliance_flagged"
    ],
    "compliance_flagged" => [
      "compliance_review",
      "compliance_approved",
      "compliance_rejected"
    ]
  }

  use Machinery,
    field: :status,
    states: @states,
    transitions: @transitions

  def states, do: @states
  def transitions, do: @transitions

  alias PhoenixFintech.Parties

  def persist(party, next_status, metadata) do
    Parties.persist_party_transition!(party, next_status, metadata)
  end
end
