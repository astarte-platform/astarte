Mimic.copy(Astarte.DataAccess.Config)
Mimic.copy(Astarte.Events.AMQPEvents)
Mimic.copy(Astarte.Events.AMQPTriggers)
Mimic.copy(Astarte.Events.TriggersHandler.Core)

{:ok, _pid} =
  Supervisor.start_link(
    [
      {Astarte.Events.AMQPEvents.Supervisor, []},
      {Astarte.Events.AMQPTriggers.Supervisor, []},
      {Astarte.Events.Triggers.Supervisor, []}
    ],
    strategy: :one_for_one,
    name: :"test_all_events_#{System.unique_integer()}"
  )

ExUnit.start(capture_logs: true)
