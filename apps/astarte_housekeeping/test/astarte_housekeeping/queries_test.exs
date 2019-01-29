#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.QueriesTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Queries

  alias Astarte.Housekeeping.DatabaseTestHelper

  @realm "test"

  test "realm creation" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@realm)
    end)

    client = CQEx.Client.new!()
    assert(Astarte.Housekeeping.Queries.create_realm(client, @realm, "testpublickey", 2) == :ok)
  end
end
