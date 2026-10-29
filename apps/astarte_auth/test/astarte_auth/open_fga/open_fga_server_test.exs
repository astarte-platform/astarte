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

defmodule Astarte.Auth.OpenFGA.ServerTest do
  # needs a running OpenFGA, each test creates its own store
  use ExUnit.Case, async: true
  use Mimic

  import Astarte.Auth.Helpers.OpenFGA

  alias Astarte.Auth.Config
  alias Astarte.Auth.OpenFGA

  @model %{
    schema_version: "1.1",
    type_definitions: [
      %{type: "user"},
      %{
        type: "realm",
        relations: %{viewer: %{this: %{}}},
        metadata: %{
          relations: %{viewer: %{directly_related_user_types: [%{type: "user"}]}}
        }
      }
    ]
  }

  setup_all do
    store_id = create_store!(unique_store_name())
    write_model!(store_id, @model)
    write_tuples!(store_id, [%{user: "user:alice", relation: "viewer", object: "realm:test"}])

    %{store_id: store_id}
  end

  setup %{store_id: store_id} do
    stub(Config, :openfga_store_id!, fn -> store_id end)
    :ok
  end

  describe "check/4" do
    test "returns :ok when a stored tuple grants the relation" do
      assert OpenFGA.check("user:alice", "viewer", "realm:test") == :ok
    end

    test "returns {:error, :forbidden} when nothing grants the relation" do
      assert OpenFGA.check("user:bob", "viewer", "realm:test") == {:error, :forbidden}
    end

    test "grants the relation through contextual tuples" do
      tuple = %{user: "user:bob", relation: "viewer", object: "realm:test"}

      assert OpenFGA.check("user:bob", "viewer", "realm:test", [tuple]) == :ok
      assert OpenFGA.check("user:bob", "viewer", "realm:test") == {:error, :forbidden}
    end
  end

  describe "fetch_store_id/1" do
    test "returns the id of the only store with that name" do
      store_name = unique_store_name()
      store_id = create_store!(store_name)

      assert OpenFGA.fetch_store_id(store_name) == {:ok, store_id}
    end

    test "returns {:error, :not_found} when no store has that name" do
      assert OpenFGA.fetch_store_id(unique_store_name()) == {:error, :not_found}
    end

    test "returns {:error, :ambiguous} when several stores have that name" do
      store_name = unique_store_name()
      create_store!(store_name)
      create_store!(store_name)

      assert OpenFGA.fetch_store_id(store_name) == {:error, :ambiguous}
    end
  end
end
