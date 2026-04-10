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
  - basic parameter validation;
  - writing normalized values into the ExUnit context;
  - tracking loaded case names in deterministic setup order.

  A case module should still own its contract by declaring accepted parameters
  and validation rules, while the mechanics are handled here.

      defmodule Astarte.TestSuite.Cases.Database do
        use Astarte.TestSuite.Case,
          name: :database,
          params: [
            database_name: [default: "astarte_test", type: :binary],
            replication_factor: [default: 1, type: :positive_integer]
          ]

        alias Astarte.TestSuite.Fixtures.Database, as: DatabaseFixtures

        setup_all [
          {DatabaseFixtures, :connect},
          {DatabaseFixtures, :keyspace}
        ]
      end

  Supported parameter rules are intentionally small and explicit:

  - `:default` gives a literal default value.
  - `:default` can also be a remote function of arity 1. It receives the map of
    values normalized so far, which is useful for derived defaults.
  - `type: :binary`, `:integer`, `:boolean`, or `:positive_integer` validates a
    scalar value.
  - `one_of: values` validates membership.
  - `list_of: :binary` validates a list of binaries.
  - `list_of: Module` validates a list of structs of that module.

  More specialized checks should stay in the case module by exposing a remote
  default function or by adding explicit normalization code before calling this
  module, depending on the contract.
  """

  alias Astarte.TestSuite.CaseContext

  defmacro __using__(opts_ast) do
    {opts, _binding} = Code.eval_quoted(opts_ast, [], __CALLER__)
    case_name = Keyword.fetch!(opts, :name)
    params = Keyword.get(opts, :params, [])

    quote do
      use ExUnit.CaseTemplate

      alias Astarte.TestSuite.Case, as: TestSuiteCase

      @astarte_test_suite_case_name unquote(case_name)
      @astarte_test_suite_params unquote(Macro.escape(params))

      using opts do
        case_name = @astarte_test_suite_case_name
        case_module = __MODULE__

        quote do
          alias unquote(case_module), as: TestSuiteCaseModule
          alias Astarte.TestSuite.CaseContext

          setup_all context do
            values = TestSuiteCaseModule.normalize_config!(unquote(opts))
            {:ok, CaseContext.put_case(context, unquote(case_name), values)}
          end
        end
      end

      def normalize_config!(config) do
        TestSuiteCase.normalize_config!(
          @astarte_test_suite_case_name,
          config,
          @astarte_test_suite_params
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
  @spec normalize_config!(atom(), keyword(), keyword()) :: map()
  def normalize_config!(case_name, config, params) do
    config = CaseContext.validate_keyword!(case_name, config, param_names(params, []))
    normalize_params(case_name, config, params, %{})
  end

  defp normalize_params(_case_name, _config, [], values), do: values

  defp normalize_params(case_name, config, [{key, rules} | rest], values) do
    value =
      config
      |> value_for_param(key, rules, values)
      |> validate_param!(case_name, key, rules)

    normalize_params(case_name, config, rest, Map.put(values, key, value))
  end

  defp value_for_param(config, key, rules, values) do
    case Keyword.fetch(config, key) do
      {:ok, value} -> value
      :error -> default_value(rules, values)
    end
  end

  defp default_value(rules, values) do
    case Keyword.fetch(rules, :default) do
      {:ok, default} -> expand_default(default, values)
      :error -> nil
    end
  end

  defp expand_default(default, values) when is_function(default, 1), do: default.(values)
  defp expand_default(default, _values), do: default

  defp validate_param!(value, case_name, key, rules) do
    value
    |> validate_type!(case_name, key, Keyword.fetch(rules, :type))
    |> validate_one_of!(case_name, key, Keyword.fetch(rules, :one_of))
    |> validate_list_of!(case_name, key, Keyword.fetch(rules, :list_of))
  end

  defp validate_type!(value, _case_name, _key, :error), do: value

  defp validate_type!(value, case_name, key, {:ok, :binary}),
    do: CaseContext.ensure_binary!(case_name, key, value)

  defp validate_type!(value, case_name, key, {:ok, :integer}),
    do: CaseContext.ensure_integer!(case_name, key, value)

  defp validate_type!(value, case_name, key, {:ok, :boolean}),
    do: CaseContext.ensure_boolean!(case_name, key, value)

  defp validate_type!(value, case_name, key, {:ok, :positive_integer}),
    do: CaseContext.ensure_positive_integer!(case_name, key, value)

  defp validate_one_of!(value, _case_name, _key, :error), do: value

  defp validate_one_of!(value, case_name, key, {:ok, allowed_values}),
    do: CaseContext.ensure_member!(case_name, key, value, allowed_values)

  defp validate_list_of!(value, _case_name, _key, :error), do: value

  defp validate_list_of!(value, case_name, key, {:ok, :binary}),
    do: CaseContext.ensure_list_of_binaries!(case_name, key, value)

  defp validate_list_of!(value, case_name, key, {:ok, module}) when is_atom(module),
    do: CaseContext.ensure_list_of_structs!(case_name, key, value, module)

  defp param_names([], acc), do: :lists.reverse(acc)
  defp param_names([{key, _rules} | rest], acc), do: param_names(rest, [key | acc])
end
