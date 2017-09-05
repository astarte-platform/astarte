defmodule Astarte.RealmManagement.API.Interfaces.RPC.AMQPClient do
  use Astarte.RPC.AMQPClient,
    rpc_queue: Application.fetch_env!(:astarte_realm_management_api, :rpc_queue),
    amqp_options: Application.get_env(:astarte_realm_management_api, :amqp_connection, [])
  use Astarte.RPC.Protocol.RealmManagement

  alias Astarte.RealmManagement.API.AlreadyInstalledInterfaceError
  alias Astarte.RealmManagement.API.InterfaceNotFoundError
  alias Astarte.RealmManagement.API.RealmNotFoundError
  alias Astarte.RealmManagement.API.InvalidInterfaceDocumentError

  def get_interface_versions_list(realm_name, interface_name) do
    {:ok, payload} = %GetInterfaceVersionsList{
        realm_name: realm_name,
        interface_name: interface_name
      }
      |> encode_and_call(:get_interface_versions_list)

    payload_to_result(payload)
  end

  def get_interfaces_list(realm_name) do
    {:ok, payload} = %GetInterfacesList{
        realm_name: realm_name
      }
      |> encode_and_call(:get_interfaces_list)

    payload_to_result(payload)
  end

  def get_interface(realm_name, interface_name, interface_major_version) do
    {:ok, payload} = %GetInterfaceSource{
        realm_name: realm_name,
        interface_name: interface_name,
        interface_major_version: interface_major_version
      }
      |> encode_and_call(:get_interface_source)

    payload_to_result(payload)
  end

  def install_interface(realm_name, interface_json) do
    {:ok, payload} = %InstallInterface{
        realm_name: realm_name,
        interface_json: interface_json,
        async_operation: true
      }
      |> encode_and_call(:install_interface)

    payload_to_result(payload)
  end

  def update_interface(realm_name, interface_json) do
    {:ok, payload} = %UpdateInterface{
        realm_name: realm_name,
        interface_json: interface_json,
        async_operation: true
      }
      |> encode_and_call(:update_interface)

    payload_to_result(payload)
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    {:ok, payload} = %DeleteInterface{
        realm_name: realm_name,
        interface_name: interface_name,
        interface_major_version: interface_major_version,
        async_operation: true
      }
      |> encode_and_call(:delete_interface)

    payload_to_result(payload)
  end

  defp encode_and_call(call, call_name) do
    %Call{
      call: {call_name, call}
    }
    |> Call.encode
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

  defp extract_result({:generic_ok_reply, _generic_reply}) do
    {:ok, :started}
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

  defp extract_error({:generic_error_reply, %GenericErrorReply{error_name: "interface_not_found"}}) do
    raise InterfaceNotFoundError
  end

  defp extract_error({:generic_error_reply, %GenericErrorReply{error_name: "realm_not_found"}}) do
    raise RealmNotFoundError
  end

  defp extract_error({:generic_error_reply, %GenericErrorReply{error_name: "already_installed_interface"}}) do
    raise AlreadyInstalledInterfaceError
  end

  defp extract_error({:generic_error_reply, %GenericErrorReply{error_name: "invalid_interface_document"}}) do
    raise InvalidInterfaceDocumentError
  end

end
