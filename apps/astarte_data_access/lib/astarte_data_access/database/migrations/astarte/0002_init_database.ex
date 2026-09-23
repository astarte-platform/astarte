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

defmodule Astarte.DataAccess.Database.Migrations.Astarte.InitDatabase do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:realms, primary_key: false) do
      add :realm_name, :string, primary_key: true
      add :replication_factor, :int
    end

    create table(:astarte_schema, primary_key: false) do
      add :config_key, :string, primary_key: true
      add :config_value, :string
    end
  end
end
