defmodule Astarte.Test.Cases.Device do
  use ExUnit.CaseTemplate
  use Astarte.Test.Cases.Interface

  using do
    quote do
      # Do nothing for now
    end
  end

  alias Astarte.Test.Setups.Device, as: DeviceSetup

  setup_all [
    {DeviceSetup, :init},
    {DeviceSetup, :setup}
  ]
end
