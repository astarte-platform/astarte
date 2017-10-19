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

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end
end
