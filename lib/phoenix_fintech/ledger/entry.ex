defmodule PhoenixFintech.Ledger.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ledger_entries" do
    field :amount, :decimal
    field :direction, Ecto.Enum, values: [:debit, :credit]
    field :currency_code, :string

    belongs_to :journal_entry, PhoenixFintech.Ledger.JournalEntry,
      foreign_key: :ledger_journal_entry_id

    belongs_to :account, PhoenixFintech.Ledger.Account, foreign_key: :ledger_account_id
    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :ledger_journal_entry_id,
      :ledger_account_id,
      :amount,
      :direction,
      :currency_code
    ])
    |> update_change(:currency_code, &String.upcase/1)
    |> validate_required([
      :ledger_journal_entry_id,
      :ledger_account_id,
      :amount,
      :direction,
      :currency_code
    ])
    |> validate_length(:currency_code, is: 3)
    |> validate_number(:amount, greater_than: 0)
  end
end
