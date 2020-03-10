#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataAccess.DatabaseTest do
  use ExUnit.Case
  alias Astarte.DataAccess.Database

  test "just connect to the database" do
    {status, _db_client} = Database.connect()

    assert status == :ok
  end

  test "connect to missing realm" do
    assert Database.connect(realm: "missing") == {:error, :database_connection_error}
  end
end
