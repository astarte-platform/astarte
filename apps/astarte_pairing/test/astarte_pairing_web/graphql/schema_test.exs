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

defmodule Astarte.PairingWeb.GraphQL.SchemaTest do
  use ExUnit.Case, async: true

  alias Astarte.PairingWeb.GraphQL.Schema
  alias Astarte.Secrets.Core

  # key_algorithm's `as:` mappings are hand-written, not generated from
  # Secrets.Core
  test "the key_algorithm enum's external mapping matches Secrets.Core" do
    %{values: values} = Absinthe.Schema.lookup_type(Schema, :key_algorithm)

    actual =
      Map.new(values, fn {identifier, %{value: internal_value}} ->
        {identifier, internal_value}
      end)

    expected =
      Core.key_algorithm_enum()
      |> Enum.filter(fn {algorithm, _name} -> algorithm in Core.asymmetric_key_algorithms() end)
      |> Map.new()

    assert actual == expected
  end
end
