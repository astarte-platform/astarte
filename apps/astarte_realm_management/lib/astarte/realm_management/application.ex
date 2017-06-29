defmodule Astarte.RealmManagement.Application do
  use Application

  def start(_type, _args) do
    Astarte.RealmManagement.Supervisor.start_link
  end
end
