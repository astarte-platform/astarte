#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.MigratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Mimic

  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Events.AMQP.Vhost
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Secrets

  setup_all do
    realm_names =
      repeatedly(fn -> "realm#{System.unique_integer([:positive])}" end)
      |> list_of(min_length: 5)
      |> Enum.at(0)

    %{realm_names: realm_names}
  end

  setup %{realm_names: realm_names} do
    Vhost
    |> stub(:create_vhost, fn _ -> :ok end)

    Secrets
    |> stub(:create_realm_kek, fn _ -> {:ok, nil} end)

    Realm
    |> stub(:list_realm_names, fn -> realm_names end)

    :ok
  end

  describe "run_realm_migrations/1" do
    test "creates vhosts for all realms", %{realm_names: realm_names} do
      for realm_name <- realm_names do
        Vhost
        |> expect(:create_vhost, fn ^realm_name -> :ok end)
      end

      assert :ok = Migrator.run_realms_migrations()
    end

    test "creates realm kek for all realms", %{realm_names: realm_names} do
      for realm_name <- realm_names do
        Secrets
        |> expect(:create_realm_kek, fn ^realm_name -> {:ok, nil} end)
      end

      assert :ok = Migrator.run_realms_migrations()
    end

    test "crashes in case of vhost creation error" do
      Vhost
      |> stub(:create_vhost, fn _ -> :error end)

      assert_raise MatchError, fn -> Migrator.run_realms_migrations() end
    end

    test "crashes in case of kek creation error" do
      Secrets
      |> stub(:create_realm_kek, fn _ -> :error end)

      assert_raise MatchError, fn -> Migrator.run_realms_migrations() end
    end

    test "returns ok with complete db" do
      assert :ok = Migrator.run_realms_migrations()
    end
  end
end
