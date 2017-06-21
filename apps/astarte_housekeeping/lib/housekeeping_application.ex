defmodule Housekeeping.Application do
  use Application

  def start(_type, _args) do
    Housekeeping.Supervisor.start_link
  end
end
