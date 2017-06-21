defmodule Housekeeping.Engine do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :housekeeping_engine)
  end

  def init(_opts) do
    CQEx.Client.new()
  end
end
