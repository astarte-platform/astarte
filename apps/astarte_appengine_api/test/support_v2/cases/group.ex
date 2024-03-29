defmodule Astarte.Test.Cases.Group do
  use ExUnit.CaseTemplate
  use Astarte.Test.Cases.Device

  using do
    quote do
      # Do nothing for now
    end
  end

  alias Astarte.Test.Setups.Group, as: GroupSetup

  setup_all [
    {GroupSetup, :init},
    {GroupSetup, :setup}
  ]
end
