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

defmodule Astarte.TestSuiteTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  alias Astarte.TestSuite.ConfigurationError

  alias Astarte.TestSuite.Case, as: TestSuiteCase
  alias Astarte.TestSuite.Cases.Device, as: DeviceCase
  alias Astarte.TestSuite.Cases.Group, as: GroupCase
  alias Astarte.TestSuite.Cases.Instance, as: InstanceCase
  alias Astarte.TestSuite.Cases.Realm, as: RealmCase

  alias Astarte.TestSuiteTest.Cases.NoParamsCase
  alias Astarte.TestSuiteTest.Cases.ParamsCase
  alias Astarte.TestSuiteTest.Helpers.Common, as: CommonHelperSupport

  doctest Astarte.TestSuite

  test "planner includes a single explicit parent with its ancestors" do
    assert %Astarte.TestSuite.Plan{
             load_order: [:common, :instance],
             graph_cases: [
               %{name: :common, config: []},
               %{name: :instance, config: []}
             ]
           } = Astarte.TestSuite.plan!(instance: true)
  end

  test "planner exposes graph metadata" do
    assert Keyword.has_key?(Astarte.TestSuite.graph(), :common)
  end

  test "planner exposes graph keys" do
    assert :group in Astarte.TestSuite.graph_keys()
  end

  test "planner accepts empty configuration" do
    assert %Astarte.TestSuite.Plan{
             load_order: [],
             graph_cases: [],
             external_cases: []
           } = Astarte.TestSuite.plan!([])
  end

  test "planner deduces ancestors from a descendant-only request" do
    assert Astarte.TestSuite.plan!(group: true).load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group
           ]
  end

  test "planner produces equal load order for random user input order" do
    first = Astarte.TestSuite.plan!(secure: true, group: true, common: true)
    second = Astarte.TestSuite.plan!(common: true, group: true, secure: true)

    assert first.load_order == second.load_order
  end

  test "planner keeps topological order for random user input order" do
    first = Astarte.TestSuite.plan!(secure: true, group: true, common: true)

    assert first.load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group,
             :conn,
             :secure
           ]
  end

  test "planner keeps dummy branch independent" do
    assert Astarte.TestSuite.plan!(dummy: true).load_order == [:common, :other, :dummy]
  end

  test "planner keeps secure branch independent" do
    assert Astarte.TestSuite.plan!(secure: true).load_order == [
             :common,
             :instance,
             :conn,
             :secure
           ]
  end

  test "planner appends external cases after graph cases" do
    assert %Astarte.TestSuite.Plan{
             load_order: [:common, :instance, :conn],
             external_cases: [
               %{module: NoParamsCase, config: []},
               %{module: ParamsCase, config: [value: 12]}
             ]
           } =
             Astarte.TestSuite.plan!(
               external_cases: [
                 NoParamsCase,
                 {ParamsCase, [value: 12]}
               ],
               conn: true
             )
  end

  test "planner accepts external_case singular entry" do
    assert %Astarte.TestSuite.Plan{
             load_order: [],
             external_cases: [
               %{module: NoParamsCase, config: []}
             ]
           } = Astarte.TestSuite.plan!(external_case: NoParamsCase)
  end

  test "planner accepts direct external module keys" do
    assert %Astarte.TestSuite.Plan{
             load_order: [],
             external_cases: [
               %{module: NoParamsCase, config: []},
               %{module: ParamsCase, config: [value: 1]}
             ]
           } =
             Astarte.TestSuite.plan!([
               {NoParamsCase, true},
               {ParamsCase, [value: 1]}
             ])
  end

  test "planner exposes deterministic load order for mixed descendants" do
    assert Astarte.TestSuite.plan!(secure: true, dummy: true, group: true).load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group,
             :conn,
             :secure,
             :other,
             :dummy
           ]
  end

  test "forced false ancestor conflicts with requested descendant" do
    assert_raise ConfigurationError,
                 ~r/:group requires :group -> :device -> :interface -> :realm -> :instance/,
                 fn ->
                   Astarte.TestSuite.plan!(group: [group_number: 4], instance: false)
                 end
  end

  test "forced false unrelated sibling does not conflict" do
    assert Astarte.TestSuite.plan!(group: true, dummy: false).load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group
           ]
  end

  test "case-level validation succeeds for group parameters" do
    assert Map.take(
             GroupCase.normalize_config!([group_number: 4], %{
               devices: %{"device" => {%{name: "device"}, "interface"}}
             }),
             [:group_name, :group_number]
           ) ==
             %{
               group_name: "group-4",
               group_number: 4
             }
  end

  test "case-level validation succeeds for device parameters" do
    assert DeviceCase.normalize_config!(
             [
               devices: %{"device-2" => {%{name: "device-2"}, "interface"}}
             ],
             interface_context()
           ).devices == %{"device-2" => {%{name: "device-2"}, "interface"}}
  end

  test "case-level validation succeeds for instance parameters" do
    assert InstanceCase.normalize_config!([], %{instance_cluster: :xandra}).instances
           |> map_size() == 1
  end

  test "case-level validation succeeds for realm parameters" do
    assert RealmCase.normalize_config!([realm_names: ["realm1"]], %{
             instances: %{"astarte1" => {"astarte1", nil}}
           }).realm_names ==
             ["realm1"]
  end

  test "group case-level validation fails from the owning case" do
    assert_raise ArgumentError, ~r/:group expects :group_number to be an integer/, fn ->
      GroupCase.normalize_config!(group_number: "4")
    end
  end

  test "device case-level validation fails from the owning case" do
    assert_raise ArgumentError, ~r/:device expects :devices to be a canonical graph map/, fn ->
      DeviceCase.normalize_config!(devices: [:not_a_device])
    end
  end

  test "case-level validation rejects unknown keys when the case decides so" do
    assert_raise ArgumentError, ~r/unknown configuration keys \[:unknown\]/, fn ->
      GroupCase.normalize_config!(unknown: true)
    end
  end

  test "common case normalizer applies defaults and validators" do
    assert TestSuiteCase.normalize_config!(
             :sample,
             [transport: :http],
             transport: [default: :mqtt, one_of: [:mqtt, :http]],
             port: [default: 1883, type: :positive_integer],
             scopes: [default: ["realm"], list_of: :binary]
           ) == %{transport: :http, port: 1883, scopes: ["realm"]}
  end

  test "unknown graph key raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/unknown Astarte.TestSuite case :unknown_case/, fn ->
      Astarte.TestSuite.plan!(unknown_case: true)
    end
  end

  test "non atom graph key raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/unknown Astarte.TestSuite case 1/, fn ->
      Astarte.TestSuite.plan!([{1, true}])
    end
  end

  test "non list configuration raises a clear TestSuite error" do
    assert_raise ConfigurationError,
                 ~r/expects a keyword list, got a non-list configuration/,
                 fn ->
                   Astarte.TestSuite.plan!(:bad)
                 end
  end

  test "non keyword list entry raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/expects a keyword list/, fn ->
      Astarte.TestSuite.plan!([:bad])
    end
  end

  test "duplicate graph case raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/case :group is configured more than once/, fn ->
      Astarte.TestSuite.plan!(group: true, group: false)
    end
  end

  test "invalid graph value raises before planning" do
    assert_raise ConfigurationError, ~r/expected true, false, or a keyword list/, fn ->
      Astarte.TestSuite.plan!(group: :yes)
    end
  end

  test "invalid graph keyword value raises before planning" do
    assert_raise ConfigurationError, ~r/expected true, false, or a keyword list/, fn ->
      Astarte.TestSuite.plan!(group: [:bad])
    end
  end

  test "invalid external case value raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/invalid external case 123/, fn ->
      Astarte.TestSuite.plan!(external_cases: [123])
    end
  end

  test "invalid external case configuration raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      Astarte.TestSuite.plan!(external_cases: [{NoParamsCase, [:bad]}])
    end
  end

  test "invalid direct external case configuration raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      Astarte.TestSuite.plan!([{NoParamsCase, [:bad]}])
    end
  end

  test "invalid direct external case scalar raises a clear TestSuite error" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      Astarte.TestSuite.plan!([{NoParamsCase, :bad}])
    end
  end

  test "use macro exposes graph plan for descendant-only request" do
    module = compile_suite!(DescendantOnlyMacroTest, group: true)

    assert module.__astarte_test_suite_plan__().load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group
           ]
  end

  test "use macro ignores caller order and keeps topological order" do
    module =
      compile_suite!(
        RandomOrderMacroTest,
        secure: [token_ttl: 60],
        group: [group_number: 4],
        instance: true,
        common: true
      )

    assert module.__astarte_test_suite_plan__().load_order == [
             :common,
             :instance,
             :realm,
             :interface,
             :device,
             :group,
             :conn,
             :secure
           ]
  end

  test "use macro appends non graph cases after graph-managed cases" do
    module =
      compile_suite!(
        MixedCasesMacroTest,
        conn: [transport: :http, port: 4000],
        external_cases: [NoParamsCase, {ParamsCase, [value: 7]}]
      )

    assert %{
             load_order: [:common, :instance, :conn],
             external_case_modules: [NoParamsCase, ParamsCase]
           } = module.__astarte_test_suite_plan__()
  end

  test "use macro accepts disabled graph cases" do
    module = compile_suite!(DisabledGraphMacroTest, group: false)

    assert %{load_order: [], external_case_modules: []} =
             module.__astarte_test_suite_plan__()
  end

  test "use macro accepts a single external case entry" do
    module = compile_suite!(SingleExternalCaseMacroTest, external_cases: NoParamsCase)

    assert %{load_order: [], external_case_modules: [NoParamsCase]} =
             module.__astarte_test_suite_plan__()
  end

  test "use macro accepts direct external module keys" do
    module =
      compile_suite!(
        DirectExternalModuleKeyMacroTest,
        [{NoParamsCase, true}, {ParamsCase, [value: 1]}]
      )

    assert %{
             load_order: [],
             external_case_modules: [NoParamsCase, ParamsCase]
           } = module.__astarte_test_suite_plan__()
  end

  test "use macro expands aliased external modules" do
    module = compile_quoted_suite!(AliasedExternalModuleMacroTest)

    assert %{
             load_order: [],
             external_case_modules: [NoParamsCase]
           } = module.__astarte_test_suite_plan__()
  end

  test "use macro rejects invalid literal compile-time configuration" do
    assert_raise ConfigurationError, ~r/expects a literal keyword list in use\/2/, fn ->
      compile_suite_ast!(InvalidUseLiteralMacroTest, quote(do: :bad))
    end
  end

  test "use macro rejects invalid literal entry compile-time configuration" do
    assert_raise ConfigurationError, ~r/expects a literal keyword list in use\/2/, fn ->
      compile_suite_ast!(InvalidUseEntryMacroTest, quote(do: [:bad]))
    end
  end

  test "use macro rejects unknown graph case compile-time configuration" do
    assert_raise ConfigurationError, ~r/unknown Astarte.TestSuite case :unknown_case/, fn ->
      compile_suite!(UnknownUseCaseMacroTest, unknown_case: true)
    end
  end

  test "use macro rejects invalid graph scalar compile-time configuration" do
    assert_raise ConfigurationError, ~r/expected true, false, or a keyword list/, fn ->
      compile_suite!(InvalidUseGraphScalarMacroTest, group: :yes)
    end
  end

  test "use macro rejects invalid graph keyword compile-time configuration" do
    assert_raise ConfigurationError, ~r/expected true, false, or a keyword list/, fn ->
      compile_suite!(InvalidUseGraphKeywordMacroTest, group: [:bad])
    end
  end

  test "use macro rejects invalid external case value compile-time configuration" do
    assert_raise ConfigurationError, ~r/invalid external case 123/, fn ->
      compile_suite!(InvalidUseExternalModuleMacroTest, external_cases: [123])
    end
  end

  test "use macro rejects invalid external case configuration compile-time configuration" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      compile_suite!(
        InvalidUseExternalConfigMacroTest,
        external_cases: [{NoParamsCase, [:bad]}]
      )
    end
  end

  test "use macro rejects invalid direct external case configuration compile-time configuration" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      compile_suite!(InvalidUseDirectExternalConfigMacroTest, [{NoParamsCase, [:bad]}])
    end
  end

  test "use macro rejects invalid direct external case scalar compile-time configuration" do
    assert_raise ConfigurationError, ~r/invalid external case/, fn ->
      compile_suite!(InvalidUseDirectExternalScalarMacroTest, [{NoParamsCase, :bad}])
    end
  end

  test "helper support module sets boot flag" do
    assert CommonHelperSupport.build_context().common_booted?
  end

  test "helper support module does not track fixture steps" do
    refute Map.has_key?(CommonHelperSupport.build_context(), :astarte_test_suite_fixture_steps)
  end

  defp compile_suite!(name, opts) do
    module = Module.concat(__MODULE__, name)

    quoted =
      quote do
        defmodule unquote(module) do
          use Astarte.TestSuite, unquote(opts)
        end
      end

    Code.compile_quoted(quoted)

    module
  end

  defp compile_suite_ast!(name, opts_ast) do
    module = Module.concat(__MODULE__, name)

    quoted =
      quote do
        defmodule unquote(module) do
          use Astarte.TestSuite, unquote(opts_ast)
        end
      end

    Code.compile_quoted(quoted)

    module
  end

  defp compile_quoted_suite!(name) do
    module = Module.concat(__MODULE__, name)

    quoted =
      quote do
        defmodule unquote(module) do
          alias Astarte.TestSuiteTest.Cases.NoParamsCase

          use Astarte.TestSuite,
            external_cases: [NoParamsCase]
        end
      end

    Code.compile_quoted(quoted)

    module
  end

  defp interface_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(:interfaces, "interface", %Interface{name: "interface"}, "realm1")
  end
end
