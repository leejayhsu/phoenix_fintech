defmodule PhoenixFintech.Compliance.Review do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["created", "manual_review", "approved", "rejected"]
  @purposes ["onboarding", "originator_status"]

  schema "compliance_reviews" do
    field :status, :string, default: "created"
    field :notes, :string
    field :purpose, :string, default: "onboarding"

    belongs_to :transfer, PhoenixFintech.Transfers.Transfer
    belongs_to :party, PhoenixFintech.Parties.Party
    belongs_to :reviewed_by_user, PhoenixFintech.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def purposes, do: @purposes

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:status, :notes, :purpose, :transfer_id, :party_id, :reviewed_by_user_id])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:purpose, @purposes)
    |> validate_subject_present()
    |> unique_constraint(:transfer_id, name: :compliance_reviews_transfer_id_index)
    |> unique_constraint([:party_id, :purpose],
      name: :compliance_reviews_party_id_purpose_unique_index
    )
    |> assoc_constraint(:transfer)
    |> assoc_constraint(:party)
    |> assoc_constraint(:reviewed_by_user)
  end

  defp validate_subject_present(changeset) do
    transfer_id = get_field(changeset, :transfer_id)
    party_id = get_field(changeset, :party_id)

    cond do
      not is_nil(transfer_id) and not is_nil(party_id) ->
        add_error(changeset, :transfer_id, "cannot be set with party_id")

      is_nil(transfer_id) and is_nil(party_id) ->
        add_error(changeset, :transfer_id, "a transfer or party subject is required")

      true ->
        changeset
    end
  end
end
