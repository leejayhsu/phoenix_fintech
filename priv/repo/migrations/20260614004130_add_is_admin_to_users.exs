defmodule PhoenixFintech.Repo.Migrations.AddIsAdminToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :is_admin, :boolean, null: false, default: false
    end

    execute "UPDATE users SET is_admin = TRUE WHERE email = 'leejayhsu@gmail.com'"
  end

  def down do
    alter table(:users) do
      remove :is_admin
    end
  end
end
