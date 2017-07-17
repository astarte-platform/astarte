defmodule Astarte.Housekeeping.API.Realms.RPC.AMQPClient do
  use Astarte.RPC.AMQPClient,
    rpc_queue: Application.fetch_env!(:astarte_housekeeping_api, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping_api, :amqp_connection, [])

  use Astarte.RPC.Protocol.Housekeeping

end
