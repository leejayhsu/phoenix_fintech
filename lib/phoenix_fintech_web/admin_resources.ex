defmodule PhoenixFintechWeb.AdminResources do
  @moduledoc false

  alias PhoenixFintech.Accounts.{User, UserToken}
  alias PhoenixFintech.Ledger.{Account, AccountBalance, Currency, Entry, JournalEntry}
  alias PhoenixFintech.Parties.{ComplianceDocument, GovernmentID, Party, PartyMember}
  alias PhoenixFintech.Transfers.{Transfer, TransferQuote}

  @groups [
    %{
      key: "accounts-access",
      label: "Accounts & access",
      resources: [
        %{key: "users", label: "Users", schema: User},
        %{key: "user_tokens", label: "User tokens", schema: UserToken}
      ]
    },
    %{
      key: "parties-compliance",
      label: "Parties & compliance",
      resources: [
        %{key: "parties", label: "Parties", schema: Party},
        %{key: "party_members", label: "Party members", schema: PartyMember},
        %{key: "government_ids", label: "Government IDs", schema: GovernmentID},
        %{
          key: "compliance_documents",
          label: "Compliance documents",
          schema: ComplianceDocument
        }
      ]
    },
    %{
      key: "transfers",
      label: "Transfers",
      resources: [
        %{key: "transfers", label: "Transfers", schema: Transfer},
        %{key: "transfer_quotes", label: "Transfer quotes", schema: TransferQuote}
      ]
    },
    %{
      key: "ledger",
      label: "Ledger",
      resources: [
        %{key: "ledger_accounts", label: "Ledger accounts", schema: Account},
        %{
          key: "ledger_account_balances",
          label: "Ledger account balances",
          schema: AccountBalance
        },
        %{key: "ledger_entries", label: "Ledger entries", schema: Entry},
        %{
          key: "ledger_journal_entries",
          label: "Ledger journal entries",
          schema: JournalEntry
        },
        %{key: "currencies", label: "Currencies", schema: Currency}
      ]
    }
  ]

  def groups, do: @groups

  def all do
    Enum.flat_map(@groups, & &1.resources)
  end
end
