defmodule SampleClient do
  @moduledoc false

  use Astarte.Config.HTTPClient, config: SampleConfig, service: :my_service
end
