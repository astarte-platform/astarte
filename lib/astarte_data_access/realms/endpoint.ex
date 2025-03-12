#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

# TODO: Copied from astarte_data_access PR #71, see: https://github.com/astarte-platform/astarte_data_access/pull/71
# use `astarte_data_access` when it will be merged
defmodule Astarte.DataAccess.Realms.Endpoint do
  use TypedEctoSchema

  alias Astarte.Core.Interface.Type, as: InterfaceType
  alias Astarte.Core.Mapping.DatabaseRetentionPolicy
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType

  alias Astarte.DataAccess.UUID
  import Ecto.Changeset

  @required_fields [:interface_id, :endpoint_id]
  @permitted_fields [
                      :allow_unset,
                      :database_retention_policy,
                      :database_retention_ttl,
                      :description,
                      :doc,
                      :endpoint,
                      :expiry,
                      :explicit_timestamp,
                      :interface_major_version,
                      :interface_minor_version,
                      :interface_name,
                      :interface_type,
                      :reliability,
                      :retention,
                      :value_type
                    ] ++ @required_fields

  @primary_key false
  typed_schema "endpoints" do
    field :interface_id, UUID, primary_key: true
    field :endpoint_id, UUID, primary_key: true
    field :allow_unset, :boolean
    field :database_retention_policy, DatabaseRetentionPolicy
    field :database_retention_ttl, :integer
    field :description, :string
    field :doc, :string
    field :endpoint, :string
    field :expiry, :integer
    field :explicit_timestamp, :boolean
    field :interface_major_version, :integer
    field :interface_minor_version, :integer
    field :interface_name, :string
    field :interface_type, InterfaceType
    field :reliability, Reliability
    field :retention, Retention
    field :value_type, ValueType
  end

  def changeset(endpoint, params \\ %{}) do
    endpoint
    |> cast(params, @permitted_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:interface_id, :endpoint_id])
  end
end
