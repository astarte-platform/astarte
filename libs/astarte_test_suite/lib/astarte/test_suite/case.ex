#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.TestSuite.Case do
  @moduledoc """
  Common building block for graph-managed `Astarte.TestSuite` cases.

  `Astarte.TestSuite.Case` wraps `ExUnit.CaseTemplate` and centralizes the
  repetitive work every reusable suite case needs:

  - the case template setup injected when the case is used;
  - forwarding the caller-provided keyword configuration to the case;
  - keyword shape validation;
  - unknown parameter detection;
  - default value application;
  - basic parameter validation through `NimbleOptions`;
  - writing normalized values into the ExUnit context;
  - tracking loaded case names in deterministic setup order.

  A case module should still own its contract by declaring accepted parameters
  and validation rules, while the mechanics are handled here.

      defmodule Astarte.TestSuite.Cases.Instance do
        use Astarte.TestSuite.Case,
          name: :instance,
          params: [
            instance_cluster: [default: :xandra, type: :atom],
            instances: [default: {InstanceHelper, :instances}, type: :graph, graph_of: :binary]
          ]

        alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures

        setup_all [
          {InstanceFixtures, :setup},
          {InstanceFixtures, :data}
        ]
      end

  Supported parameter rules are intentionally small and explicit:

  - `:default` gives a literal default value.
  - `:default` can also be a function of arity 1. It receives the ExUnit context
    merged with the values normalized so far.
  - `:default` can be `{Module, :function}`. The function is called with the
    same context used by function defaults.
  - `type: :atom`, `:binary`, `:integer`, `:boolean`, or `:positive_integer`
    validates a scalar value.
  - `one_of: values` validates membership.
  - `list_of: :binary` validates a list of binaries.
  - `list_of: Module` validates a list of structs of that module.
  - `type: :graph` declares a canonical graph collection.
  - `graph_of: Module | :map | :binary` validates graph item values.

  Graph-backed defaults and caller overrides return the canonical collection map:

      %{
        interfaces: %{
          "org.astarte.Default" => {%Interface{name: "org.astarte.Default"}, "realm1"}
        }
      }

  Materialization writes a single canonical graph collection:
  `%{entity_id => {entity, owner_id}}`. Root graph collections, such as
  `:instances`, use `nil` as owner.
  Fixtures should be reserved for operational work that can fail, touches
  external resources, or needs cleanup registered through `on_exit`.

  Validation intentionally goes through `NimbleOptions` while preserving the
  small case-facing DSL. This keeps every case focused on declaring its own
  contract without making case authors depend on a second public schema format.

  More specialized checks should stay in the case module by exposing a remote
  default function or by adding explicit normalization code before calling this
  module, depending on the contract.
  """

  alias Astarte.TestSuite.CaseContext

  defmacro __using__(opts_ast) do
    {opts, _binding} = Code.eval_quoted(opts_ast, [], __CALLER__)
    case_name = Keyword.fetch!(opts, :name)
    params = Keyword.get(opts, :params, [])
    config_function = String.to_atom("__astarte_test_suite_case_config_#{case_name}")

    quote do
      use ExUnit.CaseTemplate

      alias Astarte.TestSuite.Case, as: TestSuiteCase
      alias Astarte.TestSuite.CaseContext

      @astarte_test_suite_case_name unquote(case_name)
      @astarte_test_suite_params unquote(Macro.escape(params))

      setup_all context do
        case_module = Map.fetch!(context, :module)
        config = apply(case_module, unquote(config_function), [])

        values =
          TestSuiteCase.normalize_config!(
            @astarte_test_suite_case_name,
            config,
            @astarte_test_suite_params,
            context
          )

        {:ok, CaseContext.put_case(context, @astarte_test_suite_case_name, values)}
      end

      using opts do
        case_module = __MODULE__
        config_function = unquote(config_function)

        quote do
          alias unquote(case_module), as: TestSuiteCaseModule

          def unquote(config_function)(), do: unquote(opts)
        end
      end

      def normalize_config!(config, context \\ %{}) do
        TestSuiteCase.normalize_config!(
          @astarte_test_suite_case_name,
          config,
          @astarte_test_suite_params,
          context
        )
      end
    end
  end

  @doc """
  Normalizes a case configuration according to a parameter contract.

  The returned map is meant to be merged into the ExUnit context by the generated
  setup block. Unknown keys and invalid values raise `ArgumentError` with the
  case name and parameter name included in the message.
  """
  @spec normalize_config!(atom(), keyword(), keyword(), map()) :: map()
  def normalize_config!(case_name, config, params, context \\ %{}) do
    config = CaseContext.validate_keyword!(case_name, config, param_names(params))
    normalize_params(case_name, config, params, context, %{})
  end

  defp normalize_params(_case_name, _config, [], _context, values), do: values

  defp normalize_params(case_name, config, [{key, rules} | rest], context, values) do
    value =
      config
      |> value_for_param(key, rules, Map.merge(context, values))
      |> validate_param!(case_name, key, rules)
      |> materialize_param!(case_name, key, rules, Map.merge(context, values))

    normalize_params(case_name, config, rest, context, Map.merge(values, value))
  end

  defp value_for_param(config, key, rules, context) do
    case Keyword.fetch(config, key) do
      {:ok, value} -> expand_default(value, context)
      :error -> default_value(rules, context)
    end
  end

  defp default_value(rules, context) do
    case Keyword.fetch(rules, :default) do
      {:ok, default} -> expand_default(default, context)
      :error -> nil
    end
  end

  defp expand_default({module, function}, context) when is_atom(module) and is_atom(function),
    do: apply(module, function, [context])

  defp expand_default(default, context) when is_function(default, 1), do: default.(context)
  defp expand_default(default, _context), do: default

  defp validate_param!(value, case_name, key, rules) do
    value
    |> validate_type!(case_name, key, Keyword.fetch(rules, :type))
    |> validate_one_of!(case_name, key, Keyword.fetch(rules, :one_of))
    |> validate_list_of!(case_name, key, Keyword.fetch(rules, :list_of))
    |> validate_graph_of!(case_name, key, rules)
  end

  defp materialize_param!(value, _case_name, key, rules, context) do
    case Keyword.fetch(rules, :type) do
      {:ok, :graph} -> materialize_graph_items!(context, key, value)
      _result -> %{key => value}
    end
  end

  defp validate_type!(value, _case_name, _key, :error), do: value
  defp validate_type!(value, _case_name, _key, {:ok, :graph}), do: value

  defp validate_type!(value, case_name, key, {:ok, :binary}),
    do: validate_nimble_type!(value, case_name, key, :string, {:type, :binary})

  defp validate_type!(value, case_name, key, {:ok, :integer}),
    do: validate_nimble_type!(value, case_name, key, :integer, {:type, :integer})

  defp validate_type!(value, case_name, key, {:ok, :boolean}),
    do: validate_nimble_type!(value, case_name, key, :boolean, {:type, :boolean})

  defp validate_type!(value, case_name, key, {:ok, :atom}),
    do: validate_nimble_type!(value, case_name, key, :atom, {:type, :atom})

  defp validate_type!(value, case_name, key, {:ok, :positive_integer}),
    do: validate_nimble_type!(value, case_name, key, :pos_integer, {:type, :positive_integer})

  defp validate_one_of!(value, _case_name, _key, :error), do: value

  defp validate_one_of!(value, case_name, key, {:ok, allowed_values}),
    do:
      validate_nimble_type!(
        value,
        case_name,
        key,
        {:in, allowed_values},
        {:one_of, allowed_values}
      )

  defp validate_list_of!(value, _case_name, _key, :error), do: value

  defp validate_list_of!(value, case_name, key, {:ok, :binary}),
    do: validate_nimble_type!(value, case_name, key, {:list, :string}, {:list_of, :binary})

  defp validate_list_of!(value, case_name, key, {:ok, module}) when is_atom(module),
    do:
      validate_nimble_type!(value, case_name, key, {:list, {:struct, module}}, {:list_of, module})

  defp validate_graph_of!(value, case_name, key, rules) do
    case {Keyword.fetch(rules, :type), Keyword.fetch(rules, :graph_of)} do
      {{:ok, :graph}, {:ok, module}} -> ensure_graph_items!(value, case_name, key, module)
      {_type, _graph_of} -> value
    end
  end

  defp materialize_graph_items!(_context, collection, items) when is_map(items) do
    case Map.fetch(items, collection) do
      {:ok, graph_items} when is_map(graph_items) -> %{collection => graph_items}
      :error -> %{collection => items}
    end
  end

  defp validate_nimble_type!(value, case_name, key, type, error_context) do
    schema = [{key, [required: true, type: type]}]

    case NimbleOptions.validate([{key, value}], schema) do
      {:ok, validated} -> Keyword.fetch!(validated, key)
      {:error, _error} -> raise_validation_error!(value, case_name, key, error_context)
    end
  end

  defp raise_validation_error!(value, case_name, key, {:type, :binary}),
    do: CaseContext.ensure_binary!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:type, :integer}),
    do: CaseContext.ensure_integer!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:type, :boolean}),
    do: CaseContext.ensure_boolean!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:type, :atom}),
    do: CaseContext.ensure_atom!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:type, :positive_integer}),
    do: CaseContext.ensure_positive_integer!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:one_of, allowed_values}),
    do: CaseContext.ensure_member!(case_name, key, value, allowed_values)

  defp raise_validation_error!(value, case_name, key, {:list_of, :binary}),
    do: CaseContext.ensure_list_of_binaries!(case_name, key, value)

  defp raise_validation_error!(value, case_name, key, {:list_of, module}),
    do: CaseContext.ensure_list_of_structs!(case_name, key, value, module)

  defp ensure_graph_items!(items, case_name, key, module) do
    case graph_items?(items, key, module) do
      true -> items
      false -> raise_expected_graph_items!(case_name, key, module)
    end
  end

  defp graph_items?(items, collection, module) when is_map(items) do
    case Map.fetch(items, collection) do
      {:ok, graph_items} when is_map(graph_items) ->
        graph_collection?(graph_items, module)

      :error ->
        graph_collection?(items, module)

      _result ->
        false
    end
  end

  defp graph_items?(_items, _collection, _module), do: false

  defp graph_collection?(items, module) do
    case {graph_collection_keys?(Map.keys(items)),
          graph_collection_items?(Map.values(items), module)} do
      {true, true} -> true
      _result -> false
    end
  end

  defp graph_collection_keys?(keys), do: Enum.all?(keys, &is_binary/1)

  defp graph_collection_items?(items, module),
    do: Enum.all?(items, &graph_collection_item?(&1, module))

  defp graph_collection_item?({value, _owner_id}, module), do: graph_value?(value, module)
  defp graph_collection_item?(_item, _module), do: false

  defp graph_value?(%{__struct__: module}, module), do: true
  defp graph_value?(value, :map) when is_map(value), do: true
  defp graph_value?(value, :binary) when is_binary(value), do: true
  defp graph_value?(_value, _module), do: false

  defp raise_expected_graph_items!(case_name, key, module) do
    raise ArgumentError,
          "#{inspect(case_name)} expects #{inspect(key)} to be a canonical graph map of #{inspect(module)}"
  end

  defp param_names(params), do: Enum.map(params, &elem(&1, 0))
end
