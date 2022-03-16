#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.API.RPC.Housekeeping do
  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    DeleteRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetHealth,
    GetHealthReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply
  }

  alias Astarte.Housekeeping.API.Config
  alias Astarte.Housekeeping.API.Realms.Realm

  @rpc_client Config.rpc_client!()
  @destination Astarte.RPC.Protocol.Housekeeping.amqp_queue()

  def create_realm(%Realm{
        realm_name: realm_name,
        jwt_public_key_pem: pem,
        replication_class: "SimpleStrategy",
        replication_factor: replication_factor
      }) do
    %CreateRealm{
      realm: realm_name,
      async_operation: true,
      jwt_public_key_pem: pem,
      replication_class: :SIMPLE_STRATEGY,
      replication_factor: replication_factor
    }
    |> encode_call(:create_realm)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def create_realm(%Realm{
        realm_name: realm_name,
        jwt_public_key_pem: pem,
        replication_class: "NetworkTopologyStrategy",
        datacenter_replication_factors: replication_factors_map
      }) do
    %CreateRealm{
      realm: realm_name,
      async_operation: true,
      jwt_public_key_pem: pem,
      replication_class: :NETWORK_TOPOLOGY_STRATEGY,
      datacenter_replication_factors: Enum.to_list(replication_factors_map)
    }
    |> encode_call(:create_realm)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def list_realms do
    %GetRealmsList{}
    |> encode_call(:get_realms_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_realm(realm_name) do
    %DeleteRealm{realm: realm_name, async_operation: true}
    |> encode_call(:delete_realm)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_health do
    %GetHealth{}
    |> encode_call(:get_health)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_realm(realm_name) do
    %GetRealm{realm_name: realm_name}
    |> encode_call(:get_realm)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def realm_exists?(realm_name) do
    %DoesRealmExist{realm: realm_name}
    |> encode_call(:does_realm_exist)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  defp encode_call(call, callname) do
    %Call{call: {callname, call}}
    |> Call.encode()
  end

  defp decode_reply({:ok, encoded_reply}) when is_binary(encoded_reply) do
    %Reply{reply: reply} = Reply.decode(encoded_reply)
    reply
  end

  defp extract_reply({:does_realm_exist_reply, %DoesRealmExistReply{exists: exists}}) do
    exists
  end

  defp extract_reply({:get_realms_list_reply, %GetRealmsListReply{realms_names: realms_list}}) do
    Enum.map(realms_list, fn realm_name -> %Realm{realm_name: realm_name} end)
  end

  defp extract_reply({:get_health_reply, %GetHealthReply{status: status}}) do
    lowercase_status =
      case status do
        :READY -> :ready
        :DEGRADED -> :degraded
        :BAD -> :bad
        :ERROR -> :ERROR
      end

    {:ok, %{status: lowercase_status}}
  end

  defp extract_reply(
         {:get_realm_reply,
          %GetRealmReply{
            realm_name: realm_name,
            jwt_public_key_pem: pem,
            replication_class: :SIMPLE_STRATEGY,
            replication_factor: replication_factor
          }}
       ) do
    {:ok,
     %Realm{
       realm_name: realm_name,
       jwt_public_key_pem: pem,
       replication_class: "SimpleStrategy",
       replication_factor: replication_factor
     }}
  end

  defp extract_reply(
         {:get_realm_reply,
          %GetRealmReply{
            realm_name: realm_name,
            jwt_public_key_pem: pem,
            replication_class: :NETWORK_TOPOLOGY_STRATEGY,
            datacenter_replication_factors: datacenter_replication_factors
          }}
       ) do
    {:ok,
     %Realm{
       realm_name: realm_name,
       jwt_public_key_pem: pem,
       replication_class: "NetworkTopologyStrategy",
       datacenter_replication_factors: Enum.into(datacenter_replication_factors, %{})
     }}
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: "realm_not_found"}}) do
    {:error, :realm_not_found}
  end

  defp extract_reply(
         {:generic_error_reply, %GenericErrorReply{error_name: "realm_deletion_disabled"}}
       ) do
    {:error, :realm_deletion_disabled}
  end

  defp extract_reply(
         {:generic_error_reply, %GenericErrorReply{error_name: "connected_devices_present"}}
       ) do
    {:error, :connected_devices_present}
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    changeset = Realm.error_changeset(%Realm{})

    # Add the available infos from the error map
    error_changeset =
      Enum.reduce(error_map, changeset, fn
        {k, v}, acc when is_binary(v) and v != "" ->
          Ecto.Changeset.add_error(acc, k, v)

        _, acc ->
          acc
      end)

    {:error, error_changeset}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{async_operation: async}}) do
    if async do
      {:ok, :started}
    else
      :ok
    end
  end
end
