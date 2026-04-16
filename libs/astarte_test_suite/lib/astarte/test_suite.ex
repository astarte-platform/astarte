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

defmodule Astarte.TestSuite do
  @moduledoc """
  Graph-aware entry point for reusable Astarte test cases.

  `Astarte.TestSuite` composes reusable `ExUnit.CaseTemplate` modules into a
  deterministic test environment. A caller selects the cases needed by a test
  module, while this module resolves the dependency graph, loads ancestors,
  detects structural conflicts, and applies a stable topological order.

  Each graph-managed case owns its parameter contract through
  `Astarte.TestSuite.Case`. The suite never interprets parameter meaning: it
  forwards the keyword configuration to the selected case, and the case validates
  keys, values, defaults, and how normalized values are written into the ExUnit
  context.

  ## Usage

  A test module uses the suite directly:

      use Astarte.TestSuite,
        group: [group_number: 4],
        device: [devices: %{"device" => {%{name: "device"}, "interface"}}],
        external_cases: [MyApp.CustomCase]

  The keyword list order is irrelevant for graph-managed cases. The resulting
  load order is always derived from the suite graph.

  ## Graph

  The built-in graph is:

  common
    -> instance
      -> realm
        -> interface
          -> device
            -> group
      -> conn
        -> secure
    -> other
      -> dummy

  Requesting a descendant automatically loads its ancestors. For example,
  `group: true` loads `common`, `instance`, `realm`, `interface`, `device`, and
  `group` in that order.

  ## Case Entries

  Graph-managed case entries accept one of three shapes:

  - `true` requests the case.
  - `false` explicitly disables the case.
  - a keyword list requests the case and forwards that keyword list as the case
    configuration.

  A parameterized entry implies inclusion:

      use Astarte.TestSuite,
        group: [group_number: 4]

  The suite only forwards `[group_number: 4]`. `Astarte.TestSuite.Cases.Group`
  validates the value and writes the normalized fields into the ExUnit context.

  Graph-backed collections such as `interfaces`, `devices`, and `groups` are
  stored as a single canonical map:

      %{
        entity_id => {entity, owner_id}
      }

  Parameterized graph values use the canonical collection map:

      device: [devices: %{"device" => {%{name: "device"}, "interface"}}]

  `Astarte.TestSuite.Case` keeps that representation unchanged.

  ## Conflict Handling

  Explicit `false` entries are preserved. A contradiction between a requested
  descendant and a disabled ancestor raises `Astarte.TestSuite.ConfigurationError`
  with the dependency path involved in the conflict.

  ## External Cases

  Non-graph `ExUnit.CaseTemplate` modules are declared through `:external_cases`:

      use Astarte.TestSuite,
        instance: true,
        external_cases: [
          MyApp.ConnCase,
          {MyApp.AuthCase, [role: :admin]}
        ]

  External cases are appended after graph-managed cases in caller declaration
  order. The suite does not resolve dependencies or validate coherence for
  external cases.

  ## Introspection

  Modules using the suite receive `__astarte_test_suite_plan__/0`, which exposes
  the graph load order and external case modules selected at compile time. This
  is primarily intended for tests and diagnostics.
  """

  alias Astarte.TestSuite.ConfigurationError
  alias Astarte.TestSuite.Plan

  alias Astarte.TestSuite.Cases.Common, as: CommonCase
  alias Astarte.TestSuite.Cases.Conn, as: ConnCase
  alias Astarte.TestSuite.Cases.Device, as: DeviceCase
  alias Astarte.TestSuite.Cases.Dummy, as: DummyCase
  alias Astarte.TestSuite.Cases.Group, as: GroupCase
  alias Astarte.TestSuite.Cases.Instance, as: InstanceCase
  alias Astarte.TestSuite.Cases.Interface, as: InterfaceCase
  alias Astarte.TestSuite.Cases.Other, as: OtherCase
  alias Astarte.TestSuite.Cases.Realm, as: RealmCase
  alias Astarte.TestSuite.Cases.Secure, as: SecureCase

  @graph [
    common: [
      module: CommonCase,
      parents: []
    ],
    instance: [
      module: InstanceCase,
      parents: [:common]
    ],
    realm: [
      module: RealmCase,
      parents: [:instance]
    ],
    interface: [
      module: InterfaceCase,
      parents: [:realm]
    ],
    device: [
      module: DeviceCase,
      parents: [:interface]
    ],
    group: [
      module: GroupCase,
      parents: [:device]
    ],
    conn: [
      module: ConnCase,
      parents: [:instance]
    ],
    secure: [
      module: SecureCase,
      parents: [:conn]
    ],
    other: [
      module: OtherCase,
      parents: [:common]
    ],
    dummy: [
      module: DummyCase,
      parents: [:other]
    ]
  ]

  @graph_keys Keyword.keys(@graph)
  @external_keys [:external_cases, :external_case]

  defmacro __using__(opts) do
    caller = __CALLER__
    plan = plan_ast!(opts, caller)

    graph_uses = quoted_uses(plan.graph_cases)
    external_uses = quoted_uses(plan.external_cases)
    external_modules = expanded_external_modules(plan.external_cases, caller)

    quote do
      use ExUnit.Case

      unquote_splicing(graph_uses)
      unquote_splicing(external_uses)

      @astarte_test_suite_graph_cases unquote(Macro.escape(plan.load_order))
      @astarte_test_suite_external_case_modules unquote(Macro.escape(external_modules))

      def __astarte_test_suite_plan__ do
        %{
          load_order: @astarte_test_suite_graph_cases,
          external_case_modules: @astarte_test_suite_external_case_modules
        }
      end
    end
  end

  @doc """
  Builds the deterministic suite plan for a runtime keyword configuration.

  This function uses the same graph, dependency resolution, ordering, and
  conflict rules used by `use Astarte.TestSuite, ...`. It is useful for testing,
  diagnostics, and tooling that needs to inspect the suite plan without compiling
  a throwaway test module.
  """
  @spec plan!(keyword()) :: Plan.t()
  def plan!(opts) when is_list(opts) do
    opts
    |> parse_runtime_entries!()
    |> build_plan!()
  end

  def plan!(_opts) do
    raise ConfigurationError,
          "Astarte.TestSuite expects a keyword list, got a non-list configuration"
  end

  @doc false
  @spec graph() :: keyword()
  def graph, do: @graph

  @doc false
  @spec graph_keys() :: [atom()]
  def graph_keys, do: @graph_keys

  defp quoted_uses(entries), do: quoted_uses(entries, [])
  defp quoted_uses([], acc), do: Enum.reverse(acc)

  defp quoted_uses([%{module: module, config: config} | rest], acc) do
    quoted =
      quote do
        use unquote(module), unquote(config)
      end

    quoted_uses(rest, [quoted | acc])
  end

  defp expanded_external_modules(entries, caller),
    do: expanded_external_modules(entries, caller, [])

  defp expanded_external_modules([], _caller, acc), do: Enum.reverse(acc)

  defp expanded_external_modules([%{module: module} | rest], caller, acc) do
    expanded_external_modules(rest, caller, [expand_module(module, caller) | acc])
  end

  defp plan_ast!(opts_ast, caller) when is_list(opts_ast) do
    opts_ast
    |> parse_ast_entries!(caller)
    |> build_plan!()
  end

  defp plan_ast!(_opts_ast, _caller) do
    raise ConfigurationError,
          "Astarte.TestSuite expects a literal keyword list in use/2"
  end

  defp parse_runtime_entries!(opts), do: parse_runtime_entries(opts, new_parser_acc())
  defp parse_runtime_entries([], acc), do: acc

  defp parse_runtime_entries([entry | rest], acc) do
    parse_runtime_entries(rest, parse_runtime_entry!(entry, acc))
  end

  defp parse_runtime_entry!({key, value}, acc) do
    case entry_type(key) do
      :graph -> put_graph_request!(acc, key, parse_runtime_graph_value!(key, value))
      :external_key -> put_external_cases(acc, parse_runtime_external_cases!(value))
      :external_module -> put_external_cases(acc, [parse_runtime_external_key!(key, value)])
      :unknown -> raise_unknown_case!(key)
    end
  end

  defp parse_runtime_entry!(_entry, _acc) do
    raise ConfigurationError,
          "Astarte.TestSuite expects a keyword list"
  end

  defp parse_ast_entries!(opts_ast, caller),
    do: parse_ast_entries(opts_ast, caller, new_parser_acc())

  defp parse_ast_entries([], _caller, acc), do: acc

  defp parse_ast_entries([entry | rest], caller, acc) do
    parse_ast_entries(rest, caller, parse_ast_entry!(entry, caller, acc))
  end

  defp parse_ast_entry!({key, value_ast}, caller, acc) do
    case entry_type(key) do
      :graph -> put_graph_request!(acc, key, parse_ast_graph_value!(key, value_ast))
      :external_key -> put_external_cases(acc, parse_ast_external_cases!(value_ast, caller))
      :external_module -> put_external_cases(acc, [parse_ast_external_key!(key, value_ast)])
      :unknown -> raise_unknown_case!(key)
    end
  end

  defp parse_ast_entry!(_entry, _caller, _acc) do
    raise ConfigurationError,
          "Astarte.TestSuite expects a literal keyword list in use/2"
  end

  defp new_parser_acc, do: %{requests: %{}, external_cases: []}

  defp put_external_cases(%{external_cases: current} = acc, cases) do
    %{acc | external_cases: current ++ cases}
  end

  defp put_graph_request!(%{requests: requests} = acc, key, request) do
    case Map.fetch(requests, key) do
      :error -> %{acc | requests: Map.put(requests, key, request)}
      {:ok, _request} -> raise_duplicate_case!(key)
    end
  end

  defp raise_duplicate_case!(key) do
    raise ConfigurationError,
          "Astarte.TestSuite case #{inspect(key)} is configured more than once"
  end

  defp entry_type(key) when key in @graph_keys, do: :graph
  defp entry_type(key) when key in @external_keys, do: :external_key
  defp entry_type(key) when is_atom(key), do: external_module_entry_type(Atom.to_string(key))
  defp entry_type(_key), do: :unknown

  defp external_module_entry_type("Elixir." <> _module), do: :external_module
  defp external_module_entry_type(_key), do: :unknown

  defp parse_runtime_graph_value!(_key, true),
    do: %{included?: true, source: :boolean, config: []}

  defp parse_runtime_graph_value!(_key, false),
    do: %{included?: false, source: :boolean, config: []}

  defp parse_runtime_graph_value!(key, value) when is_list(value) do
    case Keyword.keyword?(value) do
      true -> %{included?: true, source: :configuration, config: value}
      false -> raise_invalid_graph_value!(key, value)
    end
  end

  defp parse_runtime_graph_value!(key, value), do: raise_invalid_graph_value!(key, value)

  defp parse_ast_graph_value!(_key, true),
    do: %{included?: true, source: :boolean, config: []}

  defp parse_ast_graph_value!(_key, false),
    do: %{included?: false, source: :boolean, config: []}

  defp parse_ast_graph_value!(key, value_ast) when is_list(value_ast) do
    case keyword_ast?(value_ast) do
      true -> %{included?: true, source: :configuration, config: value_ast}
      false -> raise_invalid_graph_value!(key, value_ast)
    end
  end

  defp parse_ast_graph_value!(key, value_ast), do: raise_invalid_graph_value!(key, value_ast)

  defp raise_invalid_graph_value!(key, value) do
    raise ConfigurationError,
          "invalid configuration for graph case #{inspect(key)}: expected true, false, " <>
            "or a keyword list, got #{inspect(value)}"
  end

  defp parse_runtime_external_cases!(value) when is_list(value),
    do: parse_runtime_external_cases(value, [])

  defp parse_runtime_external_cases!(value), do: [parse_runtime_external_case!(value)]
  defp parse_runtime_external_cases([], acc), do: Enum.reverse(acc)

  defp parse_runtime_external_cases([value | rest], acc) do
    parse_runtime_external_cases(rest, [parse_runtime_external_case!(value) | acc])
  end

  defp parse_runtime_external_case!(module) when is_atom(module) do
    %{module: module, config: []}
  end

  defp parse_runtime_external_case!({module, config}) when is_atom(module) and is_list(config) do
    case Keyword.keyword?(config) do
      true -> %{module: module, config: config}
      false -> raise_invalid_external_case!({module, config})
    end
  end

  defp parse_runtime_external_case!(value), do: raise_invalid_external_case!(value)

  defp parse_runtime_external_key!(module, true), do: %{module: module, config: []}

  defp parse_runtime_external_key!(module, config) when is_list(config) do
    case Keyword.keyword?(config) do
      true -> %{module: module, config: config}
      false -> raise_invalid_external_case!({module, config})
    end
  end

  defp parse_runtime_external_key!(module, value),
    do: raise_invalid_external_case!({module, value})

  defp parse_ast_external_cases!(value_ast, caller) when is_list(value_ast),
    do: parse_ast_external_cases(value_ast, caller, [])

  defp parse_ast_external_cases!(value_ast, caller),
    do: [parse_ast_external_case!(value_ast, caller)]

  defp parse_ast_external_cases([], _caller, acc), do: Enum.reverse(acc)

  defp parse_ast_external_cases([value_ast | rest], caller, acc) do
    parse_ast_external_cases(rest, caller, [parse_ast_external_case!(value_ast, caller) | acc])
  end

  defp parse_ast_external_case!({module_ast, config_ast}, _caller) when is_list(config_ast) do
    case module_ast?(module_ast) and keyword_ast?(config_ast) do
      true -> %{module: module_ast, config: config_ast}
      false -> raise_invalid_external_case!({module_ast, config_ast})
    end
  end

  defp parse_ast_external_case!(module_ast, _caller) do
    case module_ast?(module_ast) do
      true -> %{module: module_ast, config: []}
      false -> raise_invalid_external_case!(module_ast)
    end
  end

  defp parse_ast_external_key!(module, true), do: %{module: module, config: []}

  defp parse_ast_external_key!(module, config_ast) when is_list(config_ast) do
    case keyword_ast?(config_ast) do
      true -> %{module: module, config: config_ast}
      false -> raise_invalid_external_case!({module, config_ast})
    end
  end

  defp parse_ast_external_key!(module, value_ast),
    do: raise_invalid_external_case!({module, value_ast})

  defp raise_invalid_external_case!(value) do
    raise ConfigurationError,
          "invalid external case #{inspect(value)}: expected a module or {module, keyword_config}"
  end

  defp build_plan!(%{requests: requests, external_cases: external_cases}) do
    requested_cases = requested_cases(Map.to_list(requests), [])
    disabled_cases = disabled_cases(Map.to_list(requests), [])

    detect_conflicts!(requested_cases, disabled_cases)

    included_cases =
      requested_cases
      |> included_cases([])
      |> MapSet.new()

    graph_cases = graph_cases(@graph_keys, included_cases, requests, [])

    %Plan{
      graph_cases: graph_cases,
      external_cases: external_cases,
      load_order: load_order(graph_cases, [])
    }
  end

  defp requested_cases([], acc), do: acc

  defp requested_cases([{key, %{included?: true}} | rest], acc),
    do: requested_cases(rest, [key | acc])

  defp requested_cases([_entry | rest], acc), do: requested_cases(rest, acc)

  defp disabled_cases([], acc), do: acc

  defp disabled_cases([{key, %{included?: false}} | rest], acc),
    do: disabled_cases(rest, [key | acc])

  defp disabled_cases([_entry | rest], acc), do: disabled_cases(rest, acc)

  defp detect_conflicts!([], _disabled_cases), do: :ok

  defp detect_conflicts!([requested_case | rest], disabled_cases) do
    detect_request_conflicts!(requested_case, disabled_cases)
    detect_conflicts!(rest, disabled_cases)
  end

  defp detect_request_conflicts!(_requested_case, []), do: :ok

  defp detect_request_conflicts!(requested_case, [disabled_case | rest]) do
    case member?(disabled_case, ancestors_and_self(requested_case)) do
      true -> raise_conflict!(requested_case, disabled_case)
      false -> detect_request_conflicts!(requested_case, rest)
    end
  end

  defp raise_conflict!(requested_case, disabled_case) do
    path = path_between(requested_case, disabled_case)

    raise ConfigurationError,
          "conflicting Astarte.TestSuite configuration: #{inspect(requested_case)} " <>
            "requires #{format_path(path)}, but #{inspect(disabled_case)} was " <>
            "explicitly disabled"
  end

  defp included_cases([], acc), do: acc

  defp included_cases([requested_case | rest], acc) do
    included_cases(rest, ancestors_and_self(requested_case) ++ acc)
  end

  defp graph_cases([], _included_cases, _requests, acc), do: Enum.reverse(acc)

  defp graph_cases([key | rest], included_cases, requests, acc) do
    case MapSet.member?(included_cases, key) do
      true -> graph_cases(rest, included_cases, requests, [graph_case(key, requests) | acc])
      false -> graph_cases(rest, included_cases, requests, acc)
    end
  end

  defp graph_case(key, requests) do
    %{module: graph_module(key), name: key, config: graph_config(requests, key)}
  end

  defp graph_config(requests, key) do
    case Map.fetch(requests, key) do
      {:ok, %{included?: true, config: config}} -> config
      _deduced_parent -> []
    end
  end

  defp load_order([], acc), do: Enum.reverse(acc)
  defp load_order([%{name: name} | rest], acc), do: load_order(rest, [name | acc])

  defp ancestors_and_self(key), do: do_ancestors_and_self(key, [])

  defp do_ancestors_and_self(key, acc) do
    do_ancestors(graph_parents(key), [key | acc])
  end

  defp do_ancestors([], acc), do: acc

  defp do_ancestors([parent | parents], acc) do
    do_ancestors(parents, do_ancestors_and_self(parent, acc))
  end

  defp path_between(descendant, ancestor) do
    descendant
    |> descendant_path()
    |> take_until_including(ancestor, [])
  end

  defp descendant_path(key) do
    case graph_parents(key) do
      [] -> [key]
      [parent] -> [key | descendant_path(parent)]
    end
  end

  defp take_until_including([value | _rest], value, acc),
    do: Enum.reverse([value | acc])

  defp take_until_including([head | rest], value, acc),
    do: take_until_including(rest, value, [head | acc])

  defp format_path([value | rest]), do: join_inspected(rest, inspect(value))

  defp join_inspected([], acc), do: acc

  defp join_inspected([value | rest], acc),
    do: join_inspected(rest, acc <> " -> " <> inspect(value))

  defp graph_module(key), do: get_in(@graph, [key, :module])
  defp graph_parents(key), do: get_in(@graph, [key, :parents])

  defp keyword_ast?(list) when is_list(list), do: keyword_ast_entries?(list)
  defp keyword_ast_entries?([]), do: true

  defp keyword_ast_entries?([{key, _value} | rest]) when is_atom(key),
    do: keyword_ast_entries?(rest)

  defp keyword_ast_entries?([_entry | _rest]), do: false

  defp module_ast?(module) when is_atom(module), do: true
  defp module_ast?({:__aliases__, _metadata, parts}) when is_list(parts), do: true
  defp module_ast?(_module), do: false

  defp member?(_value, []), do: false
  defp member?(value, [value | _rest]), do: true
  defp member?(value, [_head | rest]), do: member?(value, rest)

  defp expand_module({:__aliases__, _metadata, _parts} = module_ast, caller),
    do: Macro.expand(module_ast, caller)

  defp expand_module(module, _caller) when is_atom(module), do: module

  defp raise_unknown_case!(key) do
    raise ConfigurationError,
          "unknown Astarte.TestSuite case #{inspect(key)}. Known graph cases are: " <>
            "#{format_path(@graph_keys)}. Use :external_cases for non-graph CaseTemplate modules."
  end
end
