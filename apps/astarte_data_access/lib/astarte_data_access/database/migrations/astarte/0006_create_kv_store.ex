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

defmodule Astarte.DataAccess.Database.Migrations.Astarte.CreateKVStore do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:kv_store, primary_key: false) do
      add :group, :string, primary_key: true
      add :key, :string, cluster_key: true
      add :value, :binary
    end
  end

  def down do
    drop table(:kv_store)
  end
end
