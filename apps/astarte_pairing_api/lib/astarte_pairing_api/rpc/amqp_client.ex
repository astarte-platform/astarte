defmodule Astarte.Pairing.API.RPC.AMQPClient do
  @moduledoc """
  This module sends RPC to the astarte_pairing backend
  """

  alias Astarte.Pairing.API.Config

  use Astarte.RPC.Protocol.Pairing
  use Astarte.RPC.AMQPClient,
    rpc_queue: Config.rpc_queue(),
    amqp_options: Config.amqp_options()

  def get_info do
    %GetInfo{}
    |> encode_call(:get_info)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  def generate_api_key(realm, hw_id) do
    %GenerateAPIKey{realm: realm, hw_id: hw_id}
    |> encode_call(:generate_api_key)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  def do_pairing(csr, api_key, device_ip) do
    %DoPairing{csr: csr, api_key: api_key, device_ip: device_ip}
    |> encode_call(:do_pairing)
    |> rpc_call()
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

  defp extract_reply({:get_info_reply, %GetInfoReply{url: url, version: version}}) do
    {:ok, %{url: url, version: version}}
  end
  defp extract_reply({:generate_api_key_reply, %GenerateAPIKeyReply{api_key: api_key}}) do
    {:ok, api_key}
  end
  defp extract_reply({:do_pairing_reply, %DoPairingReply{client_crt: client_crt}}) do
    {:ok, client_crt}
  end
  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end
end
