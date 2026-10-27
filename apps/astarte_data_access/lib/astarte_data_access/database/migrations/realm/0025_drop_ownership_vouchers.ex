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

defmodule Astarte.DataAccess.Database.Migrations.Realm.DropOwnershipVouchers do
  @moduledoc false

  use Ecto.Migration

  def up do
    drop table(:ownership_vouchers)
  end

  def down do
    create table(:ownership_vouchers, primary_key: false) do
      add :guid, :binary, primary_key: true
      add :voucher_data, :binary
      add :replacement_guid, :binary
      add :replacement_rendezvous_info, :binary
      add :replacement_public_key, :binary
      add :output_voucher, :binary
      add :key_name, :string
      add :key_algorithm, :integer
      add :user_id, :binary
      add :status, :integer
      add :device_id, :uuid
    end
  end
end
