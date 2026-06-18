defmodule PhoenixFintech.Repo.Migrations.AddDirectionToTransfers do
  use Ecto.Migration

  def change do
    alter table(:transfers) do
      add :direction, :string, default: "send", null: false
    end

    create constraint(:transfers, :direction_must_be_send_or_receive,
             check: "direction IN ('send', 'receive')"
           )
  end
end
