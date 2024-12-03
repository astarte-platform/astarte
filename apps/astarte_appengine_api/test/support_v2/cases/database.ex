defmodule Astarte.Test.Cases.Database do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Do nothing for now
    end
  end

  alias Astarte.Test.Setups.Database, as: DatabaseSetup

  setup_all [
    {DatabaseSetup, :connect},
    {DatabaseSetup, :keyspace},
    {DatabaseSetup, :setup},
    {DatabaseSetup, :setup_auth}
  ]
end
