defmodule Astarte.DataUpdaterPlant.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.DataUpdaterPlant.AMQPClient

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Registry, [keys: :unique, name: Registry.DataUpdater]},
      AMQPClient
    ]

    opts = [strategy: :one_for_one, name: Astarte.DataUpdaterPlant.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
