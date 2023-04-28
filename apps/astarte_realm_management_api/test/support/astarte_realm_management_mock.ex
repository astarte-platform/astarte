defmodule Astarte.RealmManagement.Mock do
  alias Astarte.RPC.Protocol.RealmManagement.{
    Call,
    DeleteInterface,
    GenericErrorReply,
    GenericOkReply,
    GetInterfaceSource,
    GetInterfaceSourceReply,
    GetInterfacesList,
    GetInterfacesListReply,
    GetInterfaceVersionsList,
    GetInterfaceVersionsListReply,
    GetInterfaceVersionsListReplyVersionTuple,
    GetJWTPublicKeyPEM,
    GetJWTPublicKeyPEMReply,
    InstallInterface,
    Reply,
    UpdateInterface,
    UpdateJWTPublicKeyPEM,
    InstallTriggerPolicy,
    GetTriggerPoliciesList,
    GetTriggerPoliciesListReply,
    DeleteTriggerPolicy,
    GetTriggerPolicySource,
    GetTriggerPolicySourceReply,
    DeleteDevice
  }

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.Policy
  alias Astarte.RealmManagement.Mock.DB

  def rpc_call(payload, _destination) do
    handle_rpc(payload)
  end

  def handle_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc(
         {:delete_interface,
          %DeleteInterface{
            realm_name: realm_name,
            interface_name: name,
            interface_major_version: major
          }}
       ) do
    case DB.delete_interface(realm_name, name, major) do
      :ok ->
        generic_ok()
        |> ok_wrap()

      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap()
    end
  end

  defp execute_rpc({:get_interfaces_list, %GetInterfacesList{realm_name: realm_name}}) do
    list = DB.get_interfaces_list(realm_name)

    %GetInterfacesListReply{interfaces_names: list}
    |> encode_reply(:get_interfaces_list_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:get_interface_versions_list,
          %GetInterfaceVersionsList{realm_name: realm_name, interface_name: name}}
       ) do
    list = DB.get_interface_versions_list(realm_name, name)

    versions =
      for el <- list do
        %GetInterfaceVersionsListReplyVersionTuple{
          major_version: el[:major_version],
          minor_version: el[:minor_version]
        }
      end

    %GetInterfaceVersionsListReply{versions: versions}
    |> encode_reply(:get_interface_versions_list_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_jwt_public_key_pem, %GetJWTPublicKeyPEM{realm_name: realm_name}}) do
    pem = DB.get_jwt_public_key_pem(realm_name)

    %GetJWTPublicKeyPEMReply{jwt_public_key_pem: pem}
    |> encode_reply(:get_jwt_public_key_pem_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:get_interface_source,
          %GetInterfaceSource{
            realm_name: realm_name,
            interface_name: name,
            interface_major_version: major
          }}
       ) do
    if source = DB.get_interface_source(realm_name, name, major) do
      %GetInterfaceSourceReply{source: source}
      |> encode_reply(:get_interface_source_reply)
      |> ok_wrap
    else
      generic_error(:interface_not_found)
      |> ok_wrap
    end
  end

  defp execute_rpc(
         {:install_interface,
          %InstallInterface{realm_name: realm_name, interface_json: interface_json}}
       ) do
    {:ok, params} = Jason.decode(interface_json)

    {:ok, interface} =
      Interface.changeset(%Interface{}, params) |> Ecto.Changeset.apply_action(:insert)

    with :ok <- DB.install_interface(realm_name, interface) do
      generic_ok(true)
      |> ok_wrap
    else
      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap
    end
  end

  defp execute_rpc(
         {:update_interface,
          %UpdateInterface{realm_name: realm_name, interface_json: interface_json}}
       ) do
    {:ok, params} = Jason.decode(interface_json)

    {:ok, interface} =
      Interface.changeset(%Interface{}, params) |> Ecto.Changeset.apply_action(:insert)

    with :ok <- DB.update_interface(realm_name, interface) do
      generic_ok(true)
      |> ok_wrap
    else
      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap
    end
  end

  defp execute_rpc(
         {:update_jwt_public_key_pem,
          %UpdateJWTPublicKeyPEM{realm_name: realm_name, jwt_public_key_pem: pem}}
       ) do
    :ok = DB.put_jwt_public_key_pem(realm_name, pem)

    generic_ok()
    |> ok_wrap
  end

  defp execute_rpc(
         {:install_trigger_policy,
          %InstallTriggerPolicy{realm_name: realm_name, trigger_policy_json: trigger_policy_json}}
       ) do
    {:ok, params} = Jason.decode(trigger_policy_json)

    {:ok, policy} = Policy.changeset(%Policy{}, params) |> Ecto.Changeset.apply_action(:insert)

    with :ok <- DB.install_trigger_policy(realm_name, policy) do
      generic_ok(true)
      |> ok_wrap
    else
      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap
    end
  end

  defp execute_rpc(
         {:get_trigger_policies_list,
          %GetTriggerPoliciesList{
            realm_name: realm_name
          }}
       ) do
    list = DB.get_trigger_policies_list(realm_name)

    %GetTriggerPoliciesListReply{trigger_policies_names: list}
    |> encode_reply(:get_trigger_policies_list_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:delete_trigger_policy,
          %DeleteTriggerPolicy{
            realm_name: realm_name,
            trigger_policy_name: name
          }}
       ) do
    case DB.delete_trigger_policy(realm_name, name) do
      :ok ->
        generic_ok()
        |> ok_wrap()

      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap()
    end
  end

  defp execute_rpc(
         {:get_trigger_policy_source,
          %GetTriggerPolicySource{
            realm_name: realm_name,
            trigger_policy_name: name
          }}
       ) do
    if source = DB.get_trigger_policy_source(realm_name, name) do
      %GetTriggerPolicySourceReply{source: source}
      |> encode_reply(:get_trigger_policy_source_reply)
      |> ok_wrap
    else
      generic_error(:trigger_policy_not_found)
      |> ok_wrap
    end
  end

  defp execute_rpc(
         {:delete_device,
          %DeleteDevice{
            realm_name: realm_name,
            device_id: device_id
          }}
       ) do
    with :ok <- DB.delete_device(realm_name, device_id) do
      %GenericOkReply{}
      |> encode_reply(:generic_ok_reply)
      |> ok_wrap
    else
      {:error, reason} ->
        generic_error(reason)
        |> ok_wrap
    end
  end

  defp generic_ok(async_operation \\ false) do
    %GenericOkReply{async_operation: async_operation}
    |> encode_reply(:generic_ok_reply)
  end

  defp generic_error(error_name) do
    %GenericErrorReply{error_name: to_string(error_name)}
    |> encode_reply(:generic_error_reply, error: true)
  end

  defp encode_reply(reply, reply_type, opts \\ []) do
    error = Keyword.get(opts, :error, false)

    %Reply{reply: {reply_type, reply}, error: error}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
