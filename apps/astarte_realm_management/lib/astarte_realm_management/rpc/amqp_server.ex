defmodule Astarte.RealmManagement.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_realm_management, :rpc_queue),
    amqp_options: Application.get_env(:astarte_realm_management, :amqp_connection, [])
  use Astarte.RPC.Protocol.RealmManagement

  def encode_reply(:get_interface_source, {:ok, reply}) do
    msg = %GetInterfaceSourceReply{
      source: reply
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:get_interface_source_reply, msg}})}
  end

  def encode_reply(:get_interface_versions_list, {:ok, reply}) do
    msg = %GetInterfaceVersionsListReply{
      versions: for version <- reply do
          %GetInterfaceVersionsListReplyVersionTuple{major_version: version[:major_version], minor_version: version[:minor_version]}
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

  def encode_reply(_call_atom, {:ok, :started}) do
    msg = %GenericOkReply {
      async_operation: true
    }

    {:ok, Reply.encode(%Reply{error: false, reply: {:generic_ok_reply, msg}})}
  end

  def encode_reply(_call_atom, {:error, :retry}) do
    {:error, :retry}
  end

  def encode_reply(_call_atom, {:error, reason}) when is_atom(reason) do
    {:ok, Reply.encode(
      %Reply {
        error: true,
        reply:
          {:generic_error_reply, %GenericErrorReply {
            error_name: to_string(reason)
          }}
      }
    )}
  end

  def encode_reply(_call_atom, {:error, reason}) do
    {:error, reason}
  end

  def process_rpc(payload) do
    case Call.decode(payload) do
      %Call{call: call_tuple} when call_tuple != nil ->
        case call_tuple do
          {:install_interface, %InstallInterface{realm_name: realm_name, interface_json: interface_json, async_operation: async_operation}} ->
            encode_reply(:install_interface, Astarte.RealmManagement.Engine.install_interface(realm_name, interface_json, async: async_operation))

          {:get_interface_source, %GetInterfaceSource{realm_name: realm_name, interface_name: interface_name, interface_major_version: interface_major_version}} ->
            encode_reply(:get_interface_source, Astarte.RealmManagement.Engine.interface_source(realm_name, interface_name, interface_major_version))

          {:get_interface_versions_list, %GetInterfaceVersionsList{realm_name: realm_name, interface_name: interface_name}} ->
            encode_reply(:get_interface_versions_list, Astarte.RealmManagement.Engine.list_interface_versions(realm_name, interface_name))

          {:get_interfaces_list, %GetInterfacesList{realm_name: realm_name}} ->
            encode_reply(:get_interfaces_list, Astarte.RealmManagement.Engine.get_interfaces_list(realm_name))

          {:update_interface, %UpdateInterface{realm_name: realm_name, interface_json: interface_json, async_operation: async_operation}} ->
            encode_reply(:update_interface, Astarte.RealmManagement.Engine.update_interface(realm_name, interface_json, async: async_operation))

          {:delete_interface, %DeleteInterface{realm_name: realm_name, interface_name: interface_name, interface_major_version: interface_major_version, async_operation: async_operation}} ->
            encode_reply(:delete_interface, Astarte.RealmManagement.Engine.delete_interface(realm_name, interface_name, interface_major_version, async: async_operation))

        invalid_call ->
          Logger.warn "Received unexpected call: " <> inspect invalid_call
          {:error, :unexpected_call}
        end
      invalid_message ->
        Logger.warn "Received unexpected message: " <> inspect invalid_message
        {:error, :unexpected_message}
    end
  end
end

