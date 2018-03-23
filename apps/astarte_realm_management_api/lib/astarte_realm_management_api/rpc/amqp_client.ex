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

defmodule Astarte.RealmManagement.API.RPC.AMQPClient do
  use Astarte.RPC.AMQPClient
  use Astarte.RPC.Protocol.RealmManagement

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.API.AlreadyInstalledInterfaceError
  alias Astarte.RealmManagement.API.InterfaceNotFoundError
  alias Astarte.RealmManagement.API.RealmNotFoundError
  alias Astarte.RealmManagement.API.InvalidInterfaceDocumentError

  def get_interface_versions_list(realm_name, interface_name) do
    {:ok, payload} =
      %GetInterfaceVersionsList{
        realm_name: realm_name,
        interface_name: interface_name
      }
      |> encode_and_call(:get_interface_versions_list)

    payload_to_result(payload)
  end

  def get_interfaces_list(realm_name) do
    {:ok, payload} =
      %GetInterfacesList{
        realm_name: realm_name
      }
      |> encode_and_call(:get_interfaces_list)

    payload_to_result(payload)
  end

  def get_interface(realm_name, interface_name, interface_major_version) do
    {:ok, payload} =
      %GetInterfaceSource{
        realm_name: realm_name,
        interface_name: interface_name,
        interface_major_version: interface_major_version
      }
      |> encode_and_call(:get_interface_source)

    payload_to_result(payload)
  end

  def install_interface(realm_name, interface_json) do
    {:ok, payload} =
      %InstallInterface{
        realm_name: realm_name,
        interface_json: interface_json,
        async_operation: true
      }
      |> encode_and_call(:install_interface)

    payload_to_result(payload)
  end

  def update_interface(realm_name, interface_json) do
    {:ok, payload} =
      %UpdateInterface{
        realm_name: realm_name,
        interface_json: interface_json,
        async_operation: true
      }
      |> encode_and_call(:update_interface)

    payload_to_result(payload)
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    {:ok, payload} =
      %DeleteInterface{
        realm_name: realm_name,
        interface_name: interface_name,
        interface_major_version: interface_major_version,
        async_operation: true
      }
      |> encode_and_call(:delete_interface)

    payload_to_result(payload)
  end

  def get_jwt_public_key_pem(realm_name) do
    {:ok, payload} =
      %GetJWTPublicKeyPEM{
        realm_name: realm_name
      }
      |> encode_and_call(:get_jwt_public_key_pem)

    payload_to_result(payload)
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    {:ok, payload} =
      %UpdateJWTPublicKeyPEM{
        realm_name: realm_name,
        jwt_public_key_pem: jwt_public_key_pem
      }
      |> encode_and_call(:update_jwt_public_key_pem)

    payload_to_result(payload)
  end

  def install_trigger(realm_name, trigger, simple_triggers) do
    trigger_data = Trigger.encode(trigger)

    simple_triggers_containers =
      for simple_trigger <- simple_triggers do
        %InstallTrigger.SimpleTriggerDataContainer{
          object_id: simple_trigger[:object_id],
          object_type: simple_trigger[:object_type],
          data: SimpleTriggerContainer.encode(simple_trigger[:simple_trigger])
        }
      end

    {:ok, payload} =
      %InstallTrigger{
        realm_name: realm_name,
        trigger_data: trigger_data,
        simple_triggers_data_container: simple_triggers_containers
      }
      |> encode_and_call(:install_trigger)

    payload_to_result(payload)
  end

  def get_trigger(realm_name, trigger_name) do
    {:ok, payload} =
      %GetTrigger{
        realm_name: realm_name,
        trigger_name: trigger_name
      }
      |> encode_and_call(:get_trigger)

    payload_to_result(payload)
  end

  def get_triggers_list(realm_name) do
    {:ok, payload} =
      %GetTriggersList{
        realm_name: realm_name
      }
      |> encode_and_call(:get_triggers_list)

    payload_to_result(payload)
  end

  def delete_trigger(realm_name, trigger_name) do
    {:ok, payload} =
      %DeleteTrigger{
        realm_name: realm_name,
        trigger_name: trigger_name
      }
      |> encode_and_call(:delete_trigger)

    payload_to_result(payload)
  end

  defp encode_and_call(call, call_name) do
    %Call{
      call: {call_name, call}
    }
    |> Call.encode()
    |> rpc_call
  end

  defp payload_to_result(payload) do
    Reply.decode(payload)
    |> unpack_reply
  end

  defp unpack_reply(%Reply{error: false, reply: reply}) do
    extract_result(reply)
  end

  defp unpack_reply(%Reply{error: true, reply: reply}) do
    extract_error(reply)
  end

  defp extract_result({:generic_ok_reply, %GenericOkReply{async_operation: true}}) do
    {:ok, :started}
  end

  defp extract_result({:generic_ok_reply, _generic_reply}) do
    :ok
  end

  defp extract_result({:get_interface_versions_list_reply, get_interface_versions_list_reply}) do
    for version <- get_interface_versions_list_reply.versions do
      [major_version: version.major_version, minor_version: version.minor_version]
    end
  end

  defp extract_result({:get_interfaces_list_reply, get_interfaces_list_reply}) do
    for interface_name <- get_interfaces_list_reply.interfaces_names do
      interface_name
    end
  end

  defp extract_result({:get_interface_source_reply, get_interface_source_reply}) do
    get_interface_source_reply.source
  end

  defp extract_result({:get_jwt_public_key_pem_reply, get_jwt_public_key_pem_reply}) do
    {:ok, get_jwt_public_key_pem_reply.jwt_public_key_pem}
  end

  defp extract_result({:get_trigger_reply, get_trigger_reply}) do
    trigger = Trigger.decode(get_trigger_reply.trigger_data)

    simple_triggers =
      for simple_triggers_data_container <- get_trigger_reply.simple_triggers_data_container do
        %{
          object_id: simple_triggers_data_container.object_id,
          object_type: simple_triggers_data_container.object_type,
          simple_trigger: SimpleTriggerContainer.decode(simple_triggers_data_container.data)
        }
      end

    {
      :ok,
      %{
        trigger: trigger,
        simple_triggers: simple_triggers
      }
    }
  end

  defp extract_result({:get_triggers_list_reply, get_triggers_list_reply}) do
    {:ok, get_triggers_list_reply.triggers_names}
  end

  defp extract_error(
         {:generic_error_reply, %GenericErrorReply{error_name: "public_key_not_found"}}
       ) do
    {:error, :public_key_not_found}
  end

  defp extract_error(
         {:generic_error_reply, %GenericErrorReply{error_name: "interface_not_found"}}
       ) do
    raise InterfaceNotFoundError
  end

  defp extract_error({:generic_error_reply, %GenericErrorReply{error_name: "realm_not_found"}}) do
    raise RealmNotFoundError
  end

  defp extract_error(
         {:generic_error_reply, %GenericErrorReply{error_name: "already_installed_interface"}}
       ) do
    raise AlreadyInstalledInterfaceError
  end

  defp extract_error(
         {:generic_error_reply, %GenericErrorReply{error_name: "invalid_interface_document"}}
       ) do
    raise InvalidInterfaceDocumentError
  end
end
