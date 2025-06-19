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

defmodule Astarte.Housekeeping.API.Realms.QueriesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Housekeeping.API.Helpers.Database
  alias Astarte.Housekeeping.API.Realms.Queries

  describe "is_realm_existing/1" do
    setup do
      on_exit(fn ->
        Database.teardown("testrealm")
      end)

      Database.setup("testrealm")
    end

    test "returns {:ok, true} when the realm exists" do
      assert {:ok, true} = Queries.is_realm_existing("testrealm")
    end

    test "returns {:ok, false} when the realm does not exist" do
      assert {:ok, false} = Queries.is_realm_existing("testrealm2")
    end

    test "returns {:error, _} when there is a database connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, _} = Queries.is_realm_existing("testrealm")
    end
  end
end
