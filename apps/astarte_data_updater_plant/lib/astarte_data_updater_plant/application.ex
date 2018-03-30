defmodule Astarte.DataUpdaterPlant.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer
  alias Astarte.DataUpdaterPlant.RPC.AMQPServer

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Registry, [keys: :unique, name: Registry.DataUpdater]},
      AMQPDataConsumer,
      AMQPEventsProducer,
      AMQPServer
    ]

    opts = [strategy: :one_for_one, name: Astarte.DataUpdaterPlant.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
