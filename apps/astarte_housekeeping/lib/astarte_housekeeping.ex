defmodule Astarte.Housekeeping do
  use Application

  def start(_type, _args) do
    Astarte.Housekeeping.Supervisor.start_link()
  end
end
