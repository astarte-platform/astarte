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

defmodule Astarte.DataAccess.ConsistencyTest do
  use ExUnit.Case, async: true

  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Consistency

  describe "domain_model/1" do
    test "returns configured read consistency" do
      assert Consistency.domain_model(:read) == Config.domain_model_read_consistency!()
    end

    test "returns configured write consistency" do
      assert Consistency.domain_model(:write) == Config.domain_model_write_consistency!()
    end
  end

  describe "device_info/1" do
    test "returns configured read consistency" do
      assert Consistency.device_info(:read) == Config.device_info_read_consistency!()
    end

    test "returns configured write consistency" do
      assert Consistency.device_info(:write) == Config.device_info_write_consistency!()
    end
  end

  describe "time_series/2" do
    test "returns :one for write with unreliable mapping" do
      mapping = %Mapping{reliability: :unreliable}
      assert Consistency.time_series(:write, mapping) == :one
    end

    test "returns configured consistency for write with guaranteed mapping" do
      mapping = %Mapping{reliability: :guaranteed}
      result = Consistency.time_series(:write, mapping)

      assert result == :quorum
    end

    test "returns configured consistency for write with unique mapping" do
      mapping = %Mapping{reliability: :unique}
      result = Consistency.time_series(:write, mapping)

      assert result == :one
    end

    test "returns configured consistency for read with unreliable mapping" do
      mapping = %Mapping{reliability: :unreliable}
      result = Consistency.time_series(:read, mapping)

      assert result == :one
    end

    test "returns configured consistency for read with guaranteed mapping" do
      mapping = %Mapping{reliability: :guaranteed}
      result = Consistency.time_series(:read, mapping)

      assert result == :quorum
    end
  end
end
