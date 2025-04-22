defmodule Filtrex.Condition.Number do
  use Filtrex.Condition

  @type t :: Filtrex.Condition.Number
  @moduledoc """
  `Filtrex.Condition.Number` is a specific condition type for handling
  integer and decimal filters with various configuration options.

  Comparators:
    greater than, less than or,
    greater than or, less than

  Configuration Options:

  | Key            | Type        | Description                      |
  |----------------|-------------|----------------------------------|
  | allow_decimal  | boolean     | required to allow decimal values |
  | allowed_values | list/Range  | value must be in these values    |
  """

  def type, do: :number

  def comparators, do: [
    "equals", "does not equal",
    "greater than", "less than or",
    "greater than or", "less than"
  ]

  def parse(config, %{column: column, comparator: comparator, value: value, inverse: inverse}) do
    result =
      with {:ok, parsed_value} <- parse_value(config.options, value) do
        %Condition.Number{
          type:       type(),
          inverse:    inverse,
          value:      parsed_value,
          column:     column,
          comparator: validate_in(comparator, comparators())
        }
      end

    case result do
      {:error, err} -> {:error, err}
      %Condition.Number{comparator: nil} -> {:error, parse_error(column, :comparator, type())}
      %Condition.Number{value: nil}      -> {:error, parse_value_type_error(value, type())}
      _                                   -> {:ok, result}
    end
  end

  # String → Float or Integer conversion
  defp parse_value(%{allow_decimal: true} = opts, val) when is_binary(val) do
    case Float.parse(val) do
      {f, ""} -> parse_value(opts, f)
      _       -> {:error, parse_value_type_error(val, type())}
    end
  end
  defp parse_value(opts, val) when is_binary(val) do
    case Integer.parse(val) do
      {i, ""} -> parse_value(opts, i)
      _       -> {:error, parse_value_type_error(val, type())}
    end
  end

  # Float handling with optional range or list constraint
  defp parse_value(opts, float) when is_float(float) do
    # First, reject decimals if not allowed
    if opts[:allow_decimal] == false do
      {:error, parse_value_type_error(float, type())}
    else
      case opts[:allowed_values] do
        nil ->
          {:ok, float}

        %Range{first: first, last: last} ->
          # Use Range match instead of deprecated Range.range?/1
          if float >= first and float <= last do
            {:ok, float}
          else
            {:error, "Provided number value not allowed"}
          end

        list when is_list(list) ->
          # only two cases needed: in list or not
          if float in list do
            {:ok, float}
          else
            {:error, "Provided number value not allowed"}
          end

        _other ->
          {:error, parse_value_type_error(float, type())}
      end
    end
  end

  # Integer handling with optional list constraint
  defp parse_value(opts, int) when is_integer(int) do
    case opts[:allowed_values] do
      nil ->
        {:ok, int}

      list when is_list(list) ->
        if int in list do
          {:ok, int}
        else
          {:error, "Provided number value not allowed"}
        end

      _other ->
        # non‐list / non‐nil allowed_values → treat as type error
        {:error, parse_value_type_error(int, type())}
    end
  end

  defp parse_value(_, val), do: {:error, parse_value_type_error(val, type())}

  defimpl Filtrex.Encoder do
    encoder "equals",         "does not equal", "column = ?"
    encoder "does not equal", "equals",         "column != ?"
    encoder "greater than",   "less than or",   "column > ?"
    encoder "less than or",   "greater than",   "column <= ?"
    encoder "less than",      "greater than or","column < ?"
    encoder "greater than or","less than",      "column >= ?"
  end
end
