defmodule PhoenixFintech.Compliance.ReviewStateMachine do
  @moduledoc """
  Declares the compliance review state machine.

      created -> manual_review -> approved
                          |      -> rejected
                          v
                     approved / rejected

  States:

    * `created` - initial state, awaiting first decision
    * `manual_review` - escalated for human review (e.g. after an automated
      screening flag); can move back to approved or rejected
    * `approved` - terminal, subject cleared
    * `rejected` - terminal, subject denied

  Transitions are declared as a map from each status to the set of statuses it
  may move to. `PhoenixFintech.Compliance.allowed_targets/1` is the public API
  for inspecting valid targets.
  """

  @states ["created", "manual_review", "approved", "rejected"]

  @transitions %{
    "created" => ["manual_review", "approved", "rejected"],
    "manual_review" => ["approved", "rejected"]
  }

  def states, do: @states
  def transitions, do: @transitions
end
