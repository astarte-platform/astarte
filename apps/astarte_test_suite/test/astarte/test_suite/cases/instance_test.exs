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

defmodule Astarte.TestSuite.Cases.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Cases.Instance, as: InstanceCase

  describe "instance configuration" do
    test "normalizes the default cluster" do
      assert InstanceCase.normalize_config!([]).instance_cluster == :xandra
    end

    test "normalizes an explicit cluster" do
      assert InstanceCase.normalize_config!(instance_cluster: :other).instance_cluster == :other
    end

    test "rejects an invalid cluster" do
      assert_raise ArgumentError, ~r/:instance expects :instance_cluster to be an atom/, fn ->
        InstanceCase.normalize_config!(instance_cluster: "xandra")
      end
    end

    test "rejects instance parameters" do
      assert_raise ArgumentError, ~r/unknown configuration keys/, fn ->
        InstanceCase.normalize_config!(instances: %{})
      end
    end
  end
end
