#
# This file is part of Astarte.
#
# Copyright 2018 - 2026 Clea SRL
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

defmodule Astarte.DataAccess.Interface do
  @moduledoc """
  This module defines the Ecto schema for the `interfaces` table and provides
  functions to fetch and manipulate interface information in Astarte Data Access.
  """
  use TypedEctoSchema

  import Ecto.Changeset
  import Ecto.Query

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.StorageType
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.UUID

  @required_fields [:name, :major_version]

  @permitted_fields @required_fields ++
                      [
                        :aggregation,
                        :automaton_accepting_states,
                        :automaton_transitions,
                        :description,
                        :doc,
                        :interface_id,
                        :minor_version,
                        :ownership,
                        :storage,
                        :storage_type,
                        :type
                      ]

  @default_selection [
    :name,
    :major_version,
    :minor_version,
    :interface_id,
    :type,
    :ownership,
    :aggregation,
    :storage,
    :storage_type,
    :automaton_transitions,
    :automaton_accepting_states
  ]

  @primary_key false
  typed_schema "interfaces" do
    field :name, :string, primary_key: true
    field :major_version, :integer, primary_key: true
    field :aggregation, Aggregation
    field :automaton_accepting_states, :binary
    field :automaton_transitions, :binary
    field :description, :string
    field :doc, :string
    field :interface_id, UUID
    field :minor_version, :integer
    field :ownership, Ownership
    field :storage, :string
    field :storage_type, StorageType
    field :type, Type
  end

  def changeset(interface, params) do
    interface
    |> cast(params, @permitted_fields)
    |> validate_required(@required_fields)
  end

  @spec storage(%{:aggregation => :individual | :object, :type => :datastream | :properties}) ::
          String.t()
  def storage(%{type: :properties, aggregation: :individual}),
    do: "individual_properties"

  def storage(%{type: :datastream, aggregation: :individual}),
    do: "individual_datastreams"

  def storage(%{
        type: :datastream,
        aggregation: :object,
        name: name,
        major_version: major_version
      }),
      do: CQLUtils.interface_name_to_table_name(name, major_version)

  @spec storage_type(%{
          :aggregation => :individual | :object,
          :type => :datastream | :properties
        }) ::
          :multi_interface_individual_datastream_dbtable
          | :multi_interface_individual_properties_dbtable
          | :one_object_datastream_dbtable
  def storage_type(%{type: :properties, aggregation: :individual}),
    do: :multi_interface_individual_properties_dbtable

  def storage_type(%{type: :datastream, aggregation: :individual}),
    do: :multi_interface_individual_datastream_dbtable

  def storage_type(%{type: :datastream, aggregation: :object}),
    do: :one_object_datastream_dbtable

  @spec retrieve_interface_row(String.t(), String.t(), integer, keyword()) ::
          {:ok, Interface.t()} | {:error, atom}
  def retrieve_interface_row(realm, interface_name, major_version, opts \\ []) do
    keyspace = Realm.keyspace_name(realm)

    query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^major_version]

    query =
      if Keyword.get(opts, :include_docs),
        do: query,
        else: query |> select(^@default_selection)

    consistency = Consistency.domain_model(:read)
    Repo.fetch_one(query, error: :interface_not_found, consistency: consistency)
  end

  @spec fetch_interface_descriptor(String.t(), String.t(), non_neg_integer) ::
          {:ok, InterfaceDescriptor.t()} | {:error, atom}
  def fetch_interface_descriptor(realm_name, interface_name, major_version) do
    with {:ok, interface} <- retrieve_interface_row(realm_name, interface_name, major_version) do
      InterfaceDescriptor.from_db_result(interface)
    end
  end

  @spec check_if_interface_exists(String.t(), String.t(), non_neg_integer) ::
          :ok | {:error, atom}
  def check_if_interface_exists(realm, interface_name, major_version) do
    keyspace = Realm.keyspace_name(realm)

    query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^major_version]

    consistency = Consistency.domain_model(:read)

    case Repo.some?(query, consistency: consistency) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :interface_not_found}
    end
  end
end
