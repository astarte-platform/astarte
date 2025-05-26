ExUnit.start()

children = [
  {Astarte.DataAccess, xandra_options: Astarte.DataAccess.Config.xandra_options!()}
]

Supervisor.start_link(children, strategy: :one_for_one)

Code.require_file("support/database_test_helper.exs", __DIR__)
