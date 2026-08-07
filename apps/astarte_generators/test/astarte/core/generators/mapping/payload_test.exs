#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Mapping.PayloadTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Mapping.Payload
  import Astarte.Core.Generators.Mapping.ValueType

  @moduletag :mapping
  @moduletag :payload

  @doc false
  describe "payload generator" do
    @describetag :success
    @describetag :ut

    property "generates value" do
      check all payload <- payload() do
        assert %{v: _} = payload
      end
    end

    property "generates customized value" do
      check all type <- value_type(),
                value <- value_from_type(type),
                payload <- payload(v: value) do
        assert %{v: ^value} = payload
      end
    end
  end
end
