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

  alias Astarte.TestSuite.Cases.Device, as: DeviceCase
  alias Astarte.TestSuite.Cases.Group, as: GroupCase
  alias Astarte.TestSuite.Case, as: TestSuiteCase
  alias Astarte.TestSuite.ConfigurationError
  alias Astarte.TestSuite.Mock.Device
  alias Astarte.TestSuiteTest.Cases.NoParamsCase
  alias Astarte.TestSuiteTest.Cases.ParamsCase
  alias Astarte.TestSuiteTest.Fixtures.Common, as: CommonFixtureSupport
  alias Astarte.TestSuiteTest.Helpers.Common, as: CommonHelperSupport

  doctest Astarte.TestSuite

  test "planner includes a single explicit parent with its ancestors" do
    assert %Astarte.TestSuite.Plan{
             load_order: [:common, :database],
             graph_cases: [
               %{name: :common, config: []},
               %{name: :database, config: []}
             ]
           } = Astarte.TestSuite.plan!(database: true)
  end

  test "planner deduces ancestors from a descendant-only request" do
    assert Astarte.TestSuite.plan!(group: true).load_order == [
             :common,
             :database,
             :interface,
             :device,
             :group
           ]
  end

  test "planner is independent of user input order" do
    first = Astarte.TestSuite.plan!(secure: true, group: true, common: true)
    second = Astarte.TestSuite.plan!(common: true, group: true, secure: true)

    assert first.load_order == second.load_order

    assert first.load_order == [
             :common,
             :database,
             :interface,
             :device,
             :group,
             :conn,
             :secure
           ]
  end

  test "planner keeps sibling branches independent" do
    assert Astarte.TestSuite.plan!(dummy: true).load_order == [:common, :other, :dummy]

    assert Astarte.TestSuite.plan!(secure: true).load_order == [
             :common,
             :database,
             :conn,
             :secure
           ]
  end

  test "planner appends external cases after graph cases" do
    assert %Astarte.TestSuite.Plan{
             load_order: [:common, :database, :conn],
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

  test "planner exposes deterministic load order for mixed descendants" do
    assert Astarte.TestSuite.plan!(secure: true, dummy: true, group: true).load_order == [
             :common,
             :database,
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
                 ~r/:group requires :group -> :device -> :interface -> :database/,
                 fn ->
                   Astarte.TestSuite.plan!(group: [group_number: 4], database: false)
                 end
  end

  test "forced false unrelated sibling does not conflict" do
    assert Astarte.TestSuite.plan!(group: true, dummy: false).load_order == [
             :common,
             :database,
             :interface,
             :device,
             :group
           ]
  end

  test "case-level validation succeeds for owned parameters" do
    assert GroupCase.normalize_config!(group_number: 4) == %{
             group_name: "group-4",
             group_number: 4
           }

    assert DeviceCase.normalize_config!(devices: [%Device{id: "device-2"}]) == %{
             allow_missing_credentials: false,
             devices: [%Device{id: "device-2"}]
           }
  end

  test "case-level validation fails from the owning case" do
    assert_raise ArgumentError, ~r/:group expects :group_number to be an integer/, fn ->
      GroupCase.normalize_config!(group_number: "4")
    end

    assert_raise ArgumentError, ~r/:device expects :devices to be a list/, fn ->
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

  test "invalid graph value raises before planning" do
    assert_raise ConfigurationError, ~r/expected true, false, or a keyword list/, fn ->
      Astarte.TestSuite.plan!(group: :yes)
    end
  end

  test "use macro exposes graph plan for descendant-only request" do
    module = compile_suite!(DescendantOnlyMacroTest, group: true)

    assert module.__astarte_test_suite_plan__().load_order == [
             :common,
             :database,
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
        database: true,
        common: [realm_name: "ordered"]
      )

    assert module.__astarte_test_suite_plan__().load_order == [
             :common,
             :database,
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
             load_order: [:common, :database, :conn],
             external_case_modules: [NoParamsCase, ParamsCase]
           } = module.__astarte_test_suite_plan__()
  end

  test "fixture support module delegates to production fixture" do
    context = CommonFixtureSupport.build_context()

    assert context.common_booted?
    assert context.common_realm_ready?
    assert context.astarte_test_suite_fixture_steps == [:common_boot, :common_realm]
  end

  test "helper support module delegates to production helper" do
    context = CommonHelperSupport.build_context()

    assert context.common_booted?
    assert context.common_realm_ready?
    assert context.astarte_test_suite_fixture_steps == [:common_boot, :common_realm]
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
end
