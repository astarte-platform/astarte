ExUnit.start()

children = [
  {Astarte.DataAccess, [atom_keys: true]}
]
Supervisor.start_link(children, strategy: :one_for_one)

Code.require_file("support/database_test_helper.exs", __DIR__)
