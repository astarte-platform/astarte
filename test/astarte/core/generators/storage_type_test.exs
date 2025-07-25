#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.StorageTypeTest do
  @moduledoc """
  Tests for Astarte StorageType.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.StorageType

  alias Astarte.Core.Generators.StorageType, as: StorageTypeGenerator

  @moduletag :core
  @moduletag :storage_type

  @doc false
  describe "storage_type generator" do
    @describetag :success
    @describetag :ut

    property "validate storage_type using atoms" do
      check all changes <- StorageTypeGenerator.storage_type() do
        assert {:ok, _} = StorageType.cast(changes), "Invalid cast from #{changes}"
      end
    end

    property "validate storage_type using integer" do
      gen_storage_type_changes =
        StorageTypeGenerator.storage_type() |> StorageTypeGenerator.to_changes()

      check all changes <- gen_storage_type_changes do
        assert {:ok, _} = StorageType.cast(changes), "Invalid cast from #{changes}"
      end
    end
  end
end
