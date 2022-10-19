defmodule Astarte.TriggerEngine.Policy.RetrySupervisor do
  # Automatically defines child_spec/1
  use Supervisor
  require Logger

  alias Astarte.TriggerEngine.Policy.PolicySupervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting retry supervisor", tag: "retry_supervisor_start")

    children = [
      PolicySupervisor,
      {Registry, [keys: :unique, name: Registry.PolicyRegistry]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
