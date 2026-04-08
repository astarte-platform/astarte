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

defmodule Astarte.Core.Generators.RealmTest do
  @moduledoc """
  Tests for Astarte Realm generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Realm, as: RealmGenerator
  alias Astarte.Core.Realm

  @moduletag :realm

  @doc """
  Property test for Astarte Realm generator.
  """
  describe "realm generator" do
    property "valid realm name" do
      check all(realm_name <- RealmGenerator.realm_name()) do
        assert Realm.valid_name?(realm_name), "Invalid realm name: #{inspect(realm_name)}"
      end
    end
  end
end
