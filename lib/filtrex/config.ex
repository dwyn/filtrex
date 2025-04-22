defmodule Filtrex.Type.Config do
  @moduledoc """
  This configuration struct is for passing options at the top-level (e.g. `Filtrex.parse/2`)
  in a list. See `defconfig/1` for a more specific example.

  Struct keys:
    * `type`    - the corresponding condition type (e.g. `:text`)
    * `keys`    - the allowed keys for this configuration
    * `options` - the configuration options to be passed to the condition
  """

  @type t :: %__MODULE__{
          type: atom(),
          keys: [String.t()],
          options: map()
        }

  defstruct type: nil, keys: [], options: %{}

  @doc "Returns whether the passed key is listed in any of the configurations"
  def allowed?(configs, key), do: Enum.any?(configs, &(key in &1.keys))

  @doc "Returns the configuration for the specified key"
  def config(configs, key), do: Enum.find(configs, &(key in &1.keys))

  @doc "Narrows the list of configurations to only the specified type"
  def configs_for_type(configs, type), do: Enum.filter(configs, &(&1.type == type))

  @doc "Returns the specific options of a configuration based on the key"
  def options(configs, key), do: (config(configs, key) || %__MODULE__{}).options

  @doc """
  Allows easy creation of a configuration list:

      import Filtrex.Type.Config

      defconfig do
        number :rating, allow_decimal: true
        text   [:title, :description]
        date   "posted", format: "{ISOz}"
      end
  """
  defmacro defconfig(do: block) do
    quote do
      var!(configs) = []
      unquote(block)
      var!(configs)
    end
  end

  # Generate one macro per condition type (e.g. `text/2`, `number/2`, etc.)
  for module <- Filtrex.Condition.condition_modules() do
    type = module.type()

    @doc "Generate a config struct for `#{type}`"
    defmacro unquote(type)(key_or_keys, opts \\ [])

    defmacro unquote(type)(keys, opts) when is_list(keys) do
      quote bind_quoted: [type: unquote(type), keys: keys, opts: opts] do
        var!(configs) = var!(configs) ++ [
          %Filtrex.Type.Config{
            type:    type,
            keys:    Filtrex.Type.Config.to_strings(keys),
            options: Enum.into(opts, %{})
          }
        ]
      end
    end

    defmacro unquote(type)(key, opts) do
      quote bind_quoted: [type: unquote(type), key: key, opts: opts] do
        unquote(type)([to_string(key)], opts)
      end
    end
  end

  @doc "Convert a list of mixed atoms and/or strings to a list of strings"
  def to_strings(keys) when is_list(keys),
    do: Enum.map(keys, &to_string/1)
end
