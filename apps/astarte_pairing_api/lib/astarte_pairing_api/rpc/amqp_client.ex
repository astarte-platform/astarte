defmodule Astarte.Pairing.API.RPC.AMQPClient do
  @moduledoc """
  This module sends RPC to the astarte_pairing backend
  """

  alias Astarte.Pairing.API.Config

  use Astarte.RPC.Protocol.Pairing
  use Astarte.RPC.AMQPClient,
    rpc_queue: Config.rpc_queue(),
    amqp_options: Config.amqp_options()
end
