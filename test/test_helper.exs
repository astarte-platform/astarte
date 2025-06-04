Mimic.copy(Xandra)
ExUnit.start()

children = [
  {Astarte.DataAccess, xandra_options: Astarte.DataAccess.Config.xandra_options!()}
]

Supervisor.start_link(children, strategy: :one_for_one)

# Register the Xandra cluster process so that it can be used in tests
# Yes they both have id 'Astarte.DataAccess.Repo'
Astarte.DataAccess
|> Supervisor.which_children()
# Astarte.DataAccess' child
|> Enum.find_value(fn {id, pid, _, _} -> id == Astarte.DataAccess.Repo && pid end)
|> Supervisor.which_children()
# Astarte.DataAccess.Repo's child
|> Enum.find_value(fn {id, pid, _, _} -> id == Astarte.DataAccess.Repo && pid end)
|> Process.register(:astarte_data_access_xandra)

Code.require_file("support/database_test_helper.exs", __DIR__)
