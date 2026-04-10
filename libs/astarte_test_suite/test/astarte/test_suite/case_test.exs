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

defmodule Astarte.TestSuite.CaseTest do
  use ExUnit.Case, async: true

  alias Astarte.Core.Interface
  alias Astarte.TestSuite.Case, as: TestSuiteCase

  test "normalizes literal and derived defaults" do
    params = [
      number: [default: 2, type: :integer],
      label: [default: &__MODULE__.label/1, type: :binary]
    ]

    assert TestSuiteCase.normalize_config!(:sample, [], params) == %{
             number: 2,
             label: "item-2"
           }
  end

  test "normalizes function defaults with external context" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [],
             [label: [default: &__MODULE__.label/1]],
             %{
               number: 3
             }
           ) == %{label: "item-3"}
  end

  test "normalizes module function defaults with context" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [],
             [label: [default: {__MODULE__, :label}]],
             %{
               number: 4
             }
           ) == %{label: "item-4"}
  end

  test "normalizes function overrides with external context" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [label: &__MODULE__.label/1],
             [label: [type: :binary]],
             %{
               number: 5
             }
           ) == %{label: "item-5"}
  end

  test "normalizes module function overrides with external context" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [label: {__MODULE__, :label}],
             [label: [type: :binary]],
             %{
               number: 6
             }
           ) == %{label: "item-6"}
  end

  test "normalizes params without defaults" do
    params = [value: []]

    assert TestSuiteCase.normalize_config!(:sample, [], params) == %{value: nil}
  end

  test "validates scalar rules" do
    params = [
      name: [type: :binary],
      count: [type: :integer],
      enabled: [type: :boolean],
      port: [type: :positive_integer]
    ]

    assert TestSuiteCase.normalize_config!(
             :sample,
             [name: "suite", count: 1, enabled: false, port: 1883],
             params
           ) == %{name: "suite", count: 1, enabled: false, port: 1883}
  end

  test "validates one_of rules" do
    params = [transport: [one_of: [:mqtt, :http]]]

    assert TestSuiteCase.normalize_config!(:sample, [transport: :http], params) == %{
             transport: :http
           }
  end

  test "validates list rules" do
    params = [
      scopes: [list_of: :binary],
      interfaces: [list_of: Interface]
    ]

    assert TestSuiteCase.normalize_config!(
             :sample,
             [scopes: ["realm"], interfaces: [%Interface{}]],
             params
           ) == %{scopes: ["realm"], interfaces: [%Interface{}]}
  end

  test "normalizes binary graph values" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [realms: %{"realm1" => {"realm1", "astarte1"}}],
             [realms: [type: :graph, graph_of: :binary]],
             instance_context()
           ).realms == %{"realm1" => {"realm1", "astarte1"}}
  end

  test "rejects unknown keys" do
    assert_raise ArgumentError, ~r/unknown configuration keys \[:unknown\]/, fn ->
      TestSuiteCase.normalize_config!(:sample, [unknown: true], name: [type: :binary])
    end
  end

  test "rejects invalid keyword shapes" do
    assert_raise ArgumentError, ~r/expects a keyword list configuration/, fn ->
      TestSuiteCase.normalize_config!(:sample, [:name], name: [type: :binary])
    end
  end

  test "rejects invalid one_of parameter values" do
    assert_raise ArgumentError, ~r/expects :transport to be one of/, fn ->
      TestSuiteCase.normalize_config!(:sample, [transport: :amqp], transport: [one_of: [:mqtt]])
    end
  end

  test "rejects invalid binary parameter values" do
    assert_raise ArgumentError, ~r/expects :name to be a binary/, fn ->
      TestSuiteCase.normalize_config!(:sample, [name: 1], name: [type: :binary])
    end
  end

  test "rejects invalid boolean parameter values" do
    assert_raise ArgumentError, ~r/expects :enabled to be a boolean/, fn ->
      TestSuiteCase.normalize_config!(:sample, [enabled: "true"], enabled: [type: :boolean])
    end
  end

  test "rejects invalid atom parameter values" do
    assert_raise ArgumentError, ~r/expects :cluster to be an atom/, fn ->
      TestSuiteCase.normalize_config!(:sample, [cluster: "xandra"], cluster: [type: :atom])
    end
  end

  test "rejects invalid list_of structs parameter values" do
    assert_raise ArgumentError, ~r/expects :interfaces to be a list/, fn ->
      TestSuiteCase.normalize_config!(:sample, [interfaces: [:interface]],
        interfaces: [list_of: Interface]
      )
    end
  end

  test "rejects invalid list_of binaries parameter values" do
    assert_raise ArgumentError, ~r/expects :scopes to be a list of binaries/, fn ->
      TestSuiteCase.normalize_config!(:sample, [scopes: [:realm]], scopes: [list_of: :binary])
    end
  end

  test "rejects non map graph parameters" do
    assert_raise ArgumentError, ~r/canonical graph map/, fn ->
      TestSuiteCase.normalize_config!(:sample, [items: :bad],
        items: [type: :graph, graph_of: :map]
      )
    end
  end

  test "rejects invalid graph tuples" do
    assert_raise ArgumentError, ~r/canonical graph map/, fn ->
      TestSuiteCase.normalize_config!(:sample, [items: %{"astarte1" => %{id: "astarte1"}}],
        items: [type: :graph, graph_of: :map]
      )
    end
  end

  test "rejects graph parameters with invalid graph values" do
    assert_raise ArgumentError, ~r/canonical graph map/, fn ->
      TestSuiteCase.normalize_config!(:sample, [interfaces: %{"bad" => {"bad", "realm1"}}],
        interfaces: [type: :graph, graph_of: Interface]
      )
    end
  end

  test "rejects nested graph wrappers with non map graph payloads" do
    assert_raise ArgumentError, ~r/canonical graph map/, fn ->
      TestSuiteCase.normalize_config!(:sample, [items: %{items: :bad}],
        items: [type: :graph, graph_of: :map]
      )
    end
  end

  test "case macro defines a reusable case normalizer" do
    module = Module.concat(__MODULE__, CompiledCase)

    quoted =
      quote do
        defmodule unquote(module) do
          use Astarte.TestSuite.Case,
            name: :compiled,
            params: [
              value: [default: 1, type: :integer]
            ]
        end
      end

    Code.compile_quoted(quoted)

    assert module.normalize_config!([]) == %{value: 1}
  end

  def label(%{number: number}), do: "item-#{number}"

  defp instance_context do
    %{
      instances: %{"astarte1" => {"astarte1", nil}}
    }
  end
end
