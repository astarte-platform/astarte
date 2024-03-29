defmodule Astarte.Test.Cases.Interface do
  use ExUnit.CaseTemplate
  use Astarte.Test.Cases.Database

  using do
    quote do
      # Do nothing for now
    end
  end

  alias Astarte.Test.Setups.Interface, as: InterfaceSetup

  setup_all [
    {InterfaceSetup, :init},
    {InterfaceSetup, :setup}
  ]
end
