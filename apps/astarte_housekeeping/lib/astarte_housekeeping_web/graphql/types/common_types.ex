defmodule Astarte.HousekeepingWeb.GraphQL.Types.CommonTypes do
  @moduledoc false
  use Absinthe.Schema.Notation

  @desc "A custom scalar representing arbitrary JSON data (passed as a map in variables)"
  scalar :json, open_ended: true do
    parse(fn input ->
      case unwrap(input) do
        :error -> :error
        value -> {:ok, detailed_map_to_string_keys(value)}
      end
    end)

    serialize(fn value ->
      value
    end)
  end

  defp unwrap(%Absinthe.Blueprint.Input.Object{fields: fields}) do
    Map.new(fields, fn %Absinthe.Blueprint.Input.Field{name: name, input_value: input_value} ->
      {name, unwrap(input_value.normalized)}
    end)
  end

  defp unwrap(%Absinthe.Blueprint.Input.List{items: items}) do
    Enum.map(items, fn %Absinthe.Blueprint.Input.Value{normalized: normalized} ->
      unwrap(normalized)
    end)
  end

  defp unwrap(%Absinthe.Blueprint.Input.String{value: value}), do: value
  defp unwrap(%Absinthe.Blueprint.Input.Integer{value: value}), do: value
  defp unwrap(%Absinthe.Blueprint.Input.Float{value: value}), do: value
  defp unwrap(%Absinthe.Blueprint.Input.Boolean{value: value}), do: value
  defp unwrap(%Absinthe.Blueprint.Input.Null{}), do: nil
  defp unwrap(%Absinthe.Blueprint.Input.RawValue{content: content}), do: unwrap(content)
  defp unwrap(value) when not is_struct(value), do: value
  defp unwrap(_), do: :error

  defp detailed_map_to_string_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), detailed_map_to_string_keys(v)} end)
  end

  defp detailed_map_to_string_keys(list) when is_list(list) do
    Enum.map(list, &detailed_map_to_string_keys/1)
  end

  defp detailed_map_to_string_keys(other), do: other
end
