defmodule Astarte.RealmManagement do
  use Application

  alias Astarte.RPC.Protocol.RealmManagement, as: Protocol

  alias Astarte.RealmManagement.RPC.Handler

  def start(_type, _args) do

    children = [
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]}
    ]

    opts = [strategy: :one_for_one, name: Astarte.RealmManagement.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
