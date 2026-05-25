defmodule PhoenixFintech.Ledger do
  import Ecto.Query
  alias Ecto.Multi
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Ledger.{Account, AccountBalance, Currency, Entry, JournalEntry}

  def create_currency(attrs), do: %Currency{} |> Currency.changeset(attrs) |> Repo.insert()
  def list_currencies, do: Repo.all(from c in Currency, order_by: [asc: c.code])
  def get_currency!(code), do: Repo.get!(Currency, String.upcase(code))

  def create_account(attrs), do: %Account{} |> Account.changeset(attrs) |> Repo.insert()
  def get_account!(id), do: Repo.get!(Account, id)
  def list_accounts, do: Repo.all(from a in Account, order_by: [asc: a.name])

  def get_or_create_account_balance(account_id, currency_code) do
    currency_code = String.upcase(currency_code)

    case Repo.get_by(AccountBalance, ledger_account_id: account_id, currency_code: currency_code) do
      nil ->
        %AccountBalance{}
        |> AccountBalance.changeset(%{
          ledger_account_id: account_id,
          currency_code: currency_code
        })
        |> Repo.insert()

      balance ->
        {:ok, balance}
    end
  end

  def create_journal_entry(attrs) do
    entries = Map.get(attrs, "entries", [])
    journal_changeset = JournalEntry.changeset(%JournalEntry{}, attrs)

    cond do
      !journal_changeset.valid? ->
        {:error, :journal, journal_changeset, %{}}

      !is_list(entries) or length(entries) < 2 ->
        {:error, :entries,
         Ecto.Changeset.add_error(
           journal_changeset,
           :entries,
           "must include at least two entries"
         ), %{}}

      not balances_per_currency?(entries) ->
        {:error, :entries,
         Ecto.Changeset.add_error(
           journal_changeset,
           :entries,
           "must balance debits and credits per currency"
         ), %{}}

      true ->
        do_create_journal(journal_changeset, entries)
    end
  end

  defp do_create_journal(journal_changeset, entries) do
    Multi.new()
    |> Multi.insert(:journal, journal_changeset)
    |> Multi.run(:entries, fn repo, %{journal: journal} ->
      entries
      |> Enum.map(&Map.put(&1, "ledger_journal_entry_id", journal.id))
      |> Enum.reduce_while({:ok, []}, fn entry_attrs, {:ok, acc} ->
        case %Entry{} |> Entry.changeset(entry_attrs) |> repo.insert() do
          {:ok, e} -> {:cont, {:ok, [e | acc]}}
          {:error, cs} -> {:halt, {:error, cs}}
        end
      end)
    end)
    |> Multi.run(:balances, fn repo, %{entries: entries, journal: journal} ->
      update_balances(repo, journal, entries)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{journal: journal}} -> {:ok, Repo.preload(journal, :entries)}
      {:error, :entries, cs, changes} -> {:error, :entries, cs, changes}
      {:error, step, cs, changes} -> {:error, step, cs, changes}
    end
  end

  defp update_balances(_repo, %{status: :posted}, []), do: {:ok, :done}

  defp update_balances(repo, %{status: :posted}, entries) do
    Enum.reduce_while(entries, {:ok, :done}, fn entry, _ ->
      {:ok, _} = get_or_create_account_balance(entry.ledger_account_id, entry.currency_code)

      balance =
        repo.one!(
          from b in AccountBalance,
            where:
              b.ledger_account_id == ^entry.ledger_account_id and
                b.currency_code == ^entry.currency_code,
            lock: "FOR UPDATE"
        )

      account = repo.get!(Account, entry.ledger_account_id)

      next =
        if entry.direction == :debit,
          do: Decimal.add(balance.posted_balance, entry.amount),
          else: Decimal.sub(balance.posted_balance, entry.amount)

      if not account.is_negative_balance_allowed and Decimal.compare(next, 0) == :lt do
        {:halt,
         {:error,
          Ecto.Changeset.add_error(
            AccountBalance.changeset(balance, %{}),
            :posted_balance,
            "cannot go below zero"
          )}}
      else
        case repo.update(Ecto.Changeset.change(balance, posted_balance: next)) do
          {:ok, _} -> {:cont, {:ok, :done}}
          {:error, cs} -> {:halt, {:error, cs}}
        end
      end
    end)
  end

  defp update_balances(_repo, _journal, _entries), do: {:ok, :done}

  defp balances_per_currency?(entries) do
    entries
    |> Enum.group_by(&entry_currency(&1))
    |> Enum.all?(fn {_currency, grouped} ->
      debit = sum(grouped, "debit")
      credit = sum(grouped, "credit")
      Decimal.equal?(debit, credit)
    end)
  end

  defp sum(grouped, direction) do
    grouped
    |> Enum.filter(&(Map.get(&1, "direction") == direction))
    |> Enum.reduce(Decimal.new(0), fn entry, total ->
      Decimal.add(total, Decimal.new(Map.get(entry, "amount")))
    end)
  end

  defp entry_currency(entry), do: entry |> Map.get("currency_code") |> String.upcase()

  def get_journal_entry!(id), do: Repo.get!(JournalEntry, id) |> Repo.preload(:entries)
end
