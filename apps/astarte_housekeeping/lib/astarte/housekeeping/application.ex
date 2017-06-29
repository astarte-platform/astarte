defmodule Astarte.Housekeeping.Application do
  use Application

  def start(_type, _args) do
    Astarte.Housekeeping.Supervisor.start_link
  end
end
