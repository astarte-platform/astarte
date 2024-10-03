#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevToolTest.Realm do
  use ExUnit.Case
  alias AstarteDevTool.Commands.Realm

  @nodes [
    {"localhost", "9042"}
  ]

  @realm "realm1"

  @doctest false
  @moduletag :realm
  describe "unit test" do
    test "1" do
      assert true
    end

    test "2" do
      assert :ok = Realm.Create.exec(@nodes, @realm)
    end
  end

  describe "mix tasks" do
    test "1" do
      # {:ok, private} = Mix.Tasks.AstarteDevTool.Auth.Keys.run([])
      # {:ok, public} = Mix.Tasks.AstarteDevTool.Auth.Keys.run(["--", private])
      assert 1
    end
  end
end
