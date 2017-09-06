defmodule Astarte.RealmManagement.API.Application do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Astarte.RealmManagement.APIWeb.Endpoint, []),
      worker(Astarte.RealmManagement.API.Interfaces.RPC.AMQPClient, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.RealmManagement.API.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
