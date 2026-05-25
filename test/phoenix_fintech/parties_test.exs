defmodule PhoenixFintech.PartiesTest do
  use PhoenixFintech.DataCase, async: true

  alias PhoenixFintech.Parties
  alias PhoenixFintech.Parties.{GovernmentID, Party, PartyMember}

  describe "create_originator/1" do
    test "creates a business party with its representative and government IDs" do
      attrs = %{
        "party" => %{
          "legal_name" => "Northstar Imports LLC",
          "tax_id" => "12-3456789",
          "address_line1" => "100 Market Street",
          "address_line2" => "Suite 400",
          "locality" => "San Francisco",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "party_government_id" => %{
          "type" => "ein",
          "country_code" => "US",
          "value" => "12-3456789"
        },
        "representative" => %{
          "legal_name" => "Ada Lovelace",
          "title" => "Chief Financial Officer",
          "address_line1" => "100 Market Street",
          "locality" => "San Francisco",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "representative_government_id" => %{
          "type" => "ssn",
          "country_code" => "US",
          "value" => "111-22-3333"
        }
      }

      assert {:ok, %Party{} = party} = Parties.create_originator(attrs)
      assert party.legal_name == "Northstar Imports LLC"

      loaded = Parties.get_party_with_member_tree!(party.id)

      assert [%PartyMember{} = representative] = loaded.members
      assert representative.legal_name == "Ada Lovelace"
      assert representative.is_legal_rep
      assert representative.is_ubo
      assert representative.type == :individual

      assert [%GovernmentID{type: :ein, value: "12-3456789"}] = loaded.government_ids
      assert [%GovernmentID{type: :ssn, value: "111-22-3333"}] = representative.government_ids
    end

    test "requires a valid party" do
      assert {:error, :party, changeset, %{}} =
               Parties.create_originator(%{
                 "party" => %{"legal_name" => ""},
                 "representative" => %{"legal_name" => ""}
               })

      assert %{tax_id: ["can't be blank"], legal_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows creating a party without onboarding representative" do
      attrs = %{
        "party" => %{
          "legal_name" => "No Rep LLC",
          "tax_id" => "42-4242424",
          "address_line1" => "100 Market Street",
          "locality" => "San Francisco",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "party_government_id" => %{"type" => "ein", "country_code" => "US", "value" => "42-4242424"},
        "representative" => %{},
        "representative_government_id" => %{}
      }

      assert {:ok, %Party{} = party} = Parties.create_originator(attrs)
      loaded = Parties.get_party_with_member_tree!(party.id)
      assert loaded.members == []
    end
  end

  describe "government_id_changeset/2" do
    test "requires exactly one owner" do
      changeset =
        GovernmentID.changeset(%GovernmentID{}, %{
          "type" => "ein",
          "country_code" => "US",
          "value" => "12-3456789"
        })

      refute changeset.valid?
      assert %{owner: ["must reference exactly one owner"]} = errors_on(changeset)
    end
  end
end
