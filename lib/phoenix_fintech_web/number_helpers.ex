defmodule PhoenixFintechWeb.NumberHelpers do
  @moduledoc false

  def format_currency_amount(nil, currency_code), do: "— #{currency_code}"

  def format_currency_amount(amount, currency_code) do
    "#{format_number(amount)} #{currency_code}"
  end

  def format_number(%Decimal{} = amount),
    do: amount |> Decimal.to_string(:normal) |> format_number()

  def format_number(amount) when is_integer(amount),
    do: amount |> Integer.to_string() |> format_number()

  def format_number(amount) when is_float(amount),
    do: amount |> :erlang.float_to_binary([:compact, decimals: 8]) |> format_number()

  def format_number(amount) when is_binary(amount) do
    {sign, unsigned_amount} = split_sign(amount)
    [integer_part | decimal_parts] = String.split(unsigned_amount, ".", parts: 2)

    decimal_part = Enum.at(decimal_parts, 0)
    grouped_integer = group_integer_digits(integer_part)

    case decimal_part do
      nil -> sign <> grouped_integer
      decimal -> sign <> grouped_integer <> "." <> decimal
    end
  end

  def format_number(amount), do: amount |> to_string() |> format_number()

  defp split_sign("-" <> amount), do: {"-", amount}
  defp split_sign(amount), do: {"", amount}

  defp group_integer_digits(integer_part) do
    integer_part
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map_join(",", &Enum.join/1)
  end
end
