defmodule Mix.Tasks.Astarte.Import do
  use Mix.Task
  alias Astarte.Import.CLI

  @impl Mix.Task
  @shortdoc "import data into an existing Astarte realm"
  def run(args) do
    CLI.main(args)
  end
end
