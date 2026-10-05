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

defmodule Astarte.DataAccess.Database.Migrations.Realm.DropDeviceSessions do
  @moduledoc false

  use Ecto.Migration

  def up do
    drop table(:to2_sessions)
  end

  def down do
    create table(:to2_sessions, primary_key: false, options: "WITH default_time_to_live = 7200") do
      add :guid, :binary, primary_key: true
      add :device_id, :uuid
      add :hmac, :binary
      add :nonce, :binary
      add :sig_type, :integer
      add :epid_group, :binary
      add :device_public_key, :binary
      add :prove_dv_nonce, :binary
      add :setup_dv_nonce, :binary
      add :kex_suite_name, :ascii
      add :cipher_suite_name, :integer
      add :max_owner_service_info_size, :integer
      add :owner_random, :binary
      add :secret, :binary
      add :sevk, :binary
      add :svk, :binary
      add :sek, :binary
      add :device_service_info, :"map<tuple<text, text>, blob>"
      add :owner_service_info, :"list<blob>"
      add :last_chunk_sent, :integer
      add :replacement_guid, :binary
      add :replacement_rv_info, :binary
      add :replacement_pub_key, :binary
      add :replacement_hmac, :binary
    end
  end
end
