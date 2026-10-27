#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Cases.RealmTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Cases.Realm, as: RealmCase

  test "normalizes default realm count" do
    assert RealmCase.normalize_config!([], instance_context()).realm_number == 1
  end

  test "generates default realm names" do
    assert RealmCase.normalize_config!([realm_number: 2], instance_context()).realm_names
           |> length() == 2
  end

  test "default realm names use generator path" do
    assert RealmCase.normalize_config!([], instance_context()).realm_names |> hd() |> is_binary()
  end

  test "generates default realms for the instance" do
    assert RealmCase.normalize_config!(
             [realm_number: 1],
             instance_context()
           ).realms
           |> map_size() == 1
  end

  test "normalizes explicit realm names" do
    assert RealmCase.normalize_config!(
             [realm_names: ["realm1"]],
             instance_context()
           ).realm_names == ["realm1"]
  end

  test "rejects invalid realm count" do
    assert_raise ArgumentError, ~r/:realm expects :realm_number to be a positive integer/, fn ->
      RealmCase.normalize_config!(realm_number: 0)
    end
  end

  defp instance_context do
    %{
      instances: %{"instance1" => {"instance1", nil}}
    }
  end
end
