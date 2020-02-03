defmodule Mix.Tasks.Astarte.Export do
  use Mix.Task
  alias Astarte.Export

  @impl Mix.Task
  @shortdoc "export data from an existing Astarte realm"
  def run([realm, filename]) do
    Export.export_realm_data(realm, filename)
  end
end
