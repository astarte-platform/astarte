#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.RealmManagement.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer
  use Astarte.RPC.Protocol.RealmManagement

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.Engine

  def encode_reply(:get_interface_source, {:ok, reply}) do
    msg = %GetInterfaceSourceReply{
      source: reply
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_interface_source_reply, msg}})}
  end

  def encode_reply(:get_interface_versions_list, {:ok, reply}) do
    msg = %GetInterfaceVersionsListReply{
      versions:
        for version <- reply do
          %GetInterfaceVersionsListReplyVersionTuple{
            major_version: version[:major_version],
            minor_version: version[:minor_version]
          }
        end
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_interface_versions_list_reply, msg}})}
  end

  def encode_reply(:get_interfaces_list, {:ok, reply}) do
    msg = %GetInterfacesListReply{
      interfaces_names: reply
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_interfaces_list_reply, msg}})}
  end

  def encode_reply(:get_jwt_public_key_pem, {:ok, reply}) do
    msg = %GetJWTPublicKeyPEMReply{
      jwt_public_key_pem: reply
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_jwt_public_key_pem_reply, msg}})}
  end

  def encode_reply(:update_jwt_public_key_pem, :ok) do
    {:ok, Reply.encode(%Reply{error: false, reply: {:generic_ok_reply, %GenericOkReply{}}})}
  end

  def encode_reply(:install_trigger, :ok) do
    {:ok, Reply.encode(%Reply{error: false, reply: {:generic_ok_reply, %GenericOkReply{}}})}
  end

  def encode_reply(:get_trigger, {:ok, reply}) do
    msg =
      %GetTriggerReply{
        trigger_data:  Trigger.encode(reply[:trigger]),
        simple_triggers_data_container:
          for simple_trigger <- reply[:simple_triggers] do
            %GetTriggerReply.SimpleTriggerDataContainer{
              object_id: simple_trigger[:object_id],
              object_type: simple_trigger[:object_type],
              data: SimpleTriggerContainer.encode(simple_trigger.simple_trigger)
            }
          end
        }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_trigger_reply, msg}})}
  end

  def encode_reply(:get_triggers_list, {:ok, reply}) do
    msg =
      %GetTriggersListReply{
        triggers_names: reply
      }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_triggers_list_reply, msg}})}
  end

  def encode_reply(:delete_trigger, :ok) do
    {:ok, Reply.encode(%Reply{error: false, reply: {:generic_ok_reply, %GenericOkReply{}}})}
  end

  def encode_reply(_call_atom, {:ok, :started}) do
    msg = %GenericOkReply{
      async_operation: true
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:generic_ok_reply, msg}})}
  end

  def encode_reply(_call_atom, {:error, :retry}) do
    {:error, :retry}
  end

  def encode_reply(_call_atom, {:error, reason}) when is_atom(reason) do
    {:ok,
     Reply.encode(%Reply{
       error: true,
       reply:
         {:generic_error_reply,
          %GenericErrorReply{
            error_name: to_string(reason)
          }}
     })}
  end

  def encode_reply(_call_atom, {:error, reason}) do
    {:error, reason}
  end

  def process_rpc(payload) do
    case Call.decode(payload) do
      %Call{call: call_tuple} when call_tuple != nil ->
        case call_tuple do
          {:install_interface,
           %InstallInterface{
             realm_name: realm_name,
             interface_json: interface_json,
             async_operation: async_operation
           }} ->
            encode_reply(
              :install_interface,
              Engine.install_interface(realm_name, interface_json, async: async_operation)
            )

          {:get_interface_source,
           %GetInterfaceSource{
             realm_name: realm_name,
             interface_name: interface_name,
             interface_major_version: interface_major_version
           }} ->
            encode_reply(
              :get_interface_source,
              Engine.interface_source(realm_name, interface_name, interface_major_version)
            )

          {:get_interface_versions_list,
           %GetInterfaceVersionsList{realm_name: realm_name, interface_name: interface_name}} ->
            encode_reply(
              :get_interface_versions_list,
              Engine.list_interface_versions(realm_name, interface_name)
            )

          {:get_interfaces_list, %GetInterfacesList{realm_name: realm_name}} ->
            encode_reply(:get_interfaces_list, Engine.get_interfaces_list(realm_name))

          {:update_interface,
           %UpdateInterface{
             realm_name: realm_name,
             interface_json: interface_json,
             async_operation: async_operation
           }} ->
            encode_reply(
              :update_interface,
              Engine.update_interface(realm_name, interface_json, async: async_operation)
            )

          {:delete_interface,
           %DeleteInterface{
             realm_name: realm_name,
             interface_name: interface_name,
             interface_major_version: interface_major_version,
             async_operation: async_operation
           }} ->
            encode_reply(
              :delete_interface,
              Engine.delete_interface(
                realm_name,
                interface_name,
                interface_major_version,
                async: async_operation
              )
            )

          {:get_jwt_public_key_pem, %GetJWTPublicKeyPEM{realm_name: realm_name}} ->
            encode_reply(:get_jwt_public_key_pem, Engine.get_jwt_public_key_pem(realm_name))

          {:update_jwt_public_key_pem,
           %UpdateJWTPublicKeyPEM{realm_name: realm_name, jwt_public_key_pem: pem}} ->
            encode_reply(
              :update_jwt_public_key_pem,
              Engine.update_jwt_public_key_pem(realm_name, pem)
            )

          {:install_trigger,
           %InstallTrigger{
             realm_name: realm_name,
             trigger_data: trigger_data,
             simple_triggers_data_container: simple_triggers_data_container
           }} ->
            encode_reply(
              :install_trigger,
              Engine.install_trigger(realm_name, trigger_data, simple_triggers_data_container)
            )

          {:get_trigger, %GetTrigger{realm_name: realm_name, trigger_name: trigger_name}} ->
            encode_reply(:get_trigger, Engine.get_trigger(realm_name, trigger_name))

          {:get_triggers_list, %GetTriggersList{realm_name: realm_name}} ->
            encode_reply(:get_triggers_list, Engine.get_triggers_list(realm_name))

          {:delete_trigger, %DeleteTrigger{realm_name: realm_name, trigger_name: trigger_name}} ->
            encode_reply(:delete_trigger, Engine.delete_trigger(realm_name, trigger_name))

          invalid_call ->
            Logger.warn("Received unexpected call: #{inspect(invalid_call)}")
            {:error, :unexpected_call}
        end

      invalid_message ->
        Logger.warn("Received unexpected message: #{inspect(invalid_message)}")
        {:error, :unexpected_message}
    end
  end
end
