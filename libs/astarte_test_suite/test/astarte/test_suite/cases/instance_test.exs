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

defmodule Astarte.TestSuite.Cases.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Cases.Instance, as: InstanceCase

  test "normalizes default cluster" do
    assert InstanceCase.normalize_config!([]).instance_cluster == :xandra
  end

  test "normalizes default instance count" do
    assert InstanceCase.normalize_config!([]).instance_number == 1
  end

  test "generates default instances" do
    assert InstanceCase.normalize_config!(instance_number: 2).instances
           |> map_size() == 2
  end

  test "single default instance is astarte" do
    assert InstanceCase.normalize_config!([]).instances
           |> Map.keys()
           |> hd()
           |> then(&(&1 == "astarte"))
  end

  test "keeps explicit instances" do
    instances = %{"astarte1" => {"astarte1", nil}}

    assert InstanceCase.normalize_config!(instances: instances).instances == instances
  end

  test "rejects invalid cluster" do
    assert_raise ArgumentError, ~r/:instance expects :instance_cluster to be an atom/, fn ->
      InstanceCase.normalize_config!(instance_cluster: "xandra")
    end
  end
end
