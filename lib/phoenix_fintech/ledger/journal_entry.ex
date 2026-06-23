defmodule PhoenixFintech.Ledger.JournalEntry do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ledger_journal_entries" do
    field :source_type, Ecto.Enum,
      values: [:transfer, :manual_adjustment, :fee, :provider_settlement, :reversal]

    field :source_id, :binary_id
    field :status, Ecto.Enum, values: [:posted]
    field :type, Ecto.Enum, values: [:deposit, :disbursement, :internal_fx, :internal]
    belongs_to :party, PhoenixFintech.Parties.Party
    has_many :entries, PhoenixFintech.Ledger.Entry, foreign_key: :ledger_journal_entry_id
    timestamps(type: :utc_datetime)
  end

  def changeset(journal, attrs) do
    journal
    |> cast(attrs, [:source_type, :source_id, :status, :type, :party_id])
    |> validate_required([:status, :type])
    |> validate_source_pair()
  end

  defp validate_source_pair(changeset) do
    source_type = get_field(changeset, :source_type)
    source_id = get_field(changeset, :source_id)

    if is_nil(source_type) == is_nil(source_id),
      do: changeset,
      else: add_error(changeset, :source_type, "must be paired with source_id")
  end
end
