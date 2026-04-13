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

defmodule Astarte.TestSuiteRealRealmContextTest do
  use Astarte.TestSuite,
    realm: [realm_names: ["realm1"]]

  @moduletag :real_db
  test "loads deduced graph cases in order", context do
    assert context.astarte_test_suite_loaded_cases == [:common, :instance, :realm]
  end

  test "writes common boot flag", context do
    assert context.common_booted?
  end

  test "writes default instance into canonical graph context", context do
    assert context.instances == %{"astarte" => {"astarte", nil}}
  end

  test "writes explicit realm into canonical graph context", context do
    assert context.realms == %{
             "realm1" => {%{id: "realm1", name: "realm1", instance_id: "astarte"}, "astarte"}
           }
  end
end

defmodule Astarte.TestSuiteRealInterfaceContextTest do
  use Astarte.TestSuite,
    interface: [interface_number: 1]

  @moduletag :real_db
  test "loads interface ancestors in order", context do
    assert context.astarte_test_suite_loaded_cases == [:common, :instance, :realm, :interface]
  end

  test "registers interface fixture state", context do
    assert context.interfaces_registered?
  end

  test "stores generated interfaces in canonical graph context", context do
    assert map_size(context.interfaces) == 1
  end

  test "records interface database work", context do
    assert length(context.interface_database_results) == 1
  end
end

defmodule Astarte.TestSuiteRealExternalCasesTest do
  use Astarte.TestSuite,
    instance: true,
    external_cases: [
      Astarte.TestSuiteTest.Cases.NoParamsCase,
      {Astarte.TestSuiteTest.Cases.ParamsCase, [value: 7]}
    ]

  @moduletag :real_db
  test "applies external case without params", context do
    assert context.no_params_case?
  end

  test "applies external case with params", context do
    assert context.params_case_value == 7
  end
end
