defmodule Astarte.Pairing.Mock do
  alias Astarte.Pairing.API.Config

  @test_broker_url "ssl://broker.example.com:9000"
  @test_version "1"

  use Astarte.RPC.AMQPServer,
    queue: Config.rpc_queue(),
    amqp_options: Config.amqp_options()
  use Astarte.RPC.Protocol.Pairing

  def broker_url do
    @test_broker_url
  end

  def version do
    @test_version
  end

  def process_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc({:get_info, %GetInfo{}}) do
    %GetInfoReply{url: @test_broker_url, version: @test_version}
    |> encode_reply(:get_info_reply)
    |> ok_wrap()
  end

  defp generic_error(error_name) do
    %GenericErrorReply{error_name: to_string(error_name)}
    |> encode_reply(:generic_error_reply)
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
