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

defmodule Astarte.DataUpdaterPlant.DataEncryptionKeyCacheTest do
  use Astarte.Cases.Data, async: false
  use Mimic

  alias Astarte.DataUpdaterPlant.DataEncryptionKeyCache, as: DEKCache

  setup context do
    DEKCache.reset_realm_dek(context.realm_name)
  end

  describe "dek cache" do
    test "autonomously retrieves and stores DEKs, and allows to fetch them", %{
      realm_name: realm_name
    } do
      assert {:ok, %{plaintext: _pt, ciphertext: _ct} = dek_entry} =
               DEKCache.fetch_data_encryption_key(realm_name)

      # DEK is persisting in cache
      {:ok, dek_entry_2} = DEKCache.fetch_data_encryption_key(realm_name)
      assert dek_entry == dek_entry_2
    end

    test "can be reset at runtime", %{realm_name: realm_name} do
      {:ok, dek_entry} = DEKCache.fetch_data_encryption_key(realm_name)

      # force cache reset, expect new DEK to be generated
      DEKCache.reset_realm_dek(realm_name)
      {:ok, dek_entry_renewed} = DEKCache.fetch_data_encryption_key(realm_name)
      assert dek_entry != dek_entry_renewed
    end

    test "returns an error if a DEK could not be renewed", %{realm_name: realm_name} do
      Mimic.expect(Astarte.Secrets, :generate_dek, fn _, _ ->
        {:error, "something bad happened"}
      end)

      assert {:error, :dek_generation_error} == DEKCache.fetch_data_encryption_key(realm_name)
    end
  end
end
