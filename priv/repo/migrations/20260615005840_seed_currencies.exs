defmodule PhoenixFintech.Repo.Migrations.SeedCurrencies do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO currencies (code, name, minor_unit, inserted_at, updated_at)
    VALUES
      ('USD', 'United States Dollar', 2, now(), now()),
      ('EUR', 'Euro', 2, now(), now()),
      ('GBP', 'British Pound', 2, now(), now()),
      ('JPY', 'Japanese Yen', 0, now(), now()),
      ('CNY', 'Chinese Yuan', 2, now(), now()),
      ('BRL', 'Brazilian Real', 2, now(), now()),
      ('MXN', 'Mexican Peso', 2, now(), now())
    ON CONFLICT (code) DO UPDATE SET
      name = EXCLUDED.name,
      minor_unit = EXCLUDED.minor_unit,
      updated_at = EXCLUDED.updated_at
    """
  end

  def down do
    execute """
    DELETE FROM currencies
    WHERE code IN ('USD', 'EUR', 'GBP', 'JPY', 'CNY', 'BRL', 'MXN')
    """
  end
end
