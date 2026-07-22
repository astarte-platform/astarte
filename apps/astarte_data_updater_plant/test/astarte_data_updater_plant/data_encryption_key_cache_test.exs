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

    # gathering telemetry events for the DEK cache status
    telemetry_handler_ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:astarte, :data_updater_plant, :realm_dek, :status]
      ])

    on_exit(fn -> :telemetry.detach(telemetry_handler_ref) end)

    %{telemetry_handler_ref: telemetry_handler_ref}
  end

  describe "dek cache" do
    test "autonomously retrieves and stores DEKs, and allows to fetch them", %{
      realm_name: realm_name,
      telemetry_handler_ref: telemetry_handler_ref
    } do
      assert {:ok, %{plaintext: _pt, ciphertext: _ct} = dek_entry} =
               DEKCache.fetch_data_encryption_key(realm_name)

      # telemetry event is emitted notifying successful setting of DEK
      assert_received {[:astarte, :data_updater_plant, :realm_dek, :status],
                       ^telemetry_handler_ref, %{}, %{realm: ^realm_name, status: :set}}

      # DEK is persisting in cache
      {:ok, dek_entry_2} = DEKCache.fetch_data_encryption_key(realm_name)
      assert dek_entry == dek_entry_2
    end

    test "can be reset at runtime", %{
      realm_name: realm_name,
      telemetry_handler_ref: telemetry_handler_ref
    } do
      {:ok, dek_entry} = DEKCache.fetch_data_encryption_key(realm_name)

      # force cache reset, expect new DEK to be generated at next retrieval
      DEKCache.reset_realm_dek(realm_name)

      # telemetry event is emitted notifying deletion of DEK
      assert_received {[:astarte, :data_updater_plant, :realm_dek, :status],
                       ^telemetry_handler_ref, %{}, %{realm: ^realm_name, status: :not_set}}

      {:ok, dek_entry_renewed} = DEKCache.fetch_data_encryption_key(realm_name)
      assert dek_entry != dek_entry_renewed
    end

    test "returns an error if a DEK could not be renewed", %{
      realm_name: realm_name,
      telemetry_handler_ref: telemetry_handler_ref
    } do
      Mimic.expect(Astarte.Secrets, :generate_dek, fn _, _ ->
        {:error, "something bad happened"}
      end)

      assert {:error, :dek_generation_error} == DEKCache.fetch_data_encryption_key(realm_name)

      # telemetry event is emitted notifying failed setting of DEK
      assert_received {[:astarte, :data_updater_plant, :realm_dek, :status],
                       ^telemetry_handler_ref, %{}, %{realm: ^realm_name, status: :failed}}
    end
  end
end
