defmodule Astarte.DataUpdaterPlant.VHostSupervisor do
  use DynamicSupervisor
  require Logger

  alias Astarte.DataUpdaterPlant.AMQPTriggersProducer
  @impl true
  def init(_init_arg) do
    Logger.info("AMQPTriggers dynamic supervisor init.", tag: "amqp_triggers_sup_init")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def for_realm(realm_name) do
    server_name = server_from_realm(realm_name)

    child =
      {AMQPTriggersProducer,
       [
         realm: realm_name,
         server: server_name
       ]}

    case DynamicSupervisor.start_child(
           __MODULE__,
           child
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start child #{inspect(child)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def server_from_realm(realm_name) do
    {:via, Registry, {Astarte.DataUpdaterPlant.VhostRegistry, {:amqp_producer, realm_name}}}
  end
end
