defmodule Mix.Tasks.Astarte.Import do
  use Mix.Task
  require Logger
  alias Astarte.Import.CLI
  alias Astarte.DataAccess.Config

  @impl Mix.Task
  @shortdoc "import data into an existing Astarte realm"
  def run(args) do
    Logger.info("Running astarte import task with arguments: #{inspect(args)}")

    # Process the arguments
    case args do
      [realm, file_name] ->
        Config.validate!()

        xandra_options = Config.xandra_options!()
        data_access_opts = [xandra_options: xandra_options]

        ae_xandra_opts = Keyword.put(xandra_options, :name, :xandra)

        children = [
          # Ensure the :astarte_data_access process is started
          {Xandra.Cluster, ae_xandra_opts},
          {Astarte.DataAccess, data_access_opts}
        ]

        opts = [strategy: :one_for_one, name: AstarteImport.Supervisor]
        Supervisor.start_link(children, opts)

        CLI.main(realm, file_name)

      [realm, file_name, db_host_and_port] ->
        Config.validate!()

        xandra_options = Config.xandra_options!()

        xandra_options =
          if Keyword.has_key?(xandra_options, :nodes),
            do: Keyword.put(xandra_options, :nodes, [db_host_and_port]),
            else: xandra_options

        data_access_opts = [xandra_options: xandra_options]

        ae_xandra_opts = Keyword.put(xandra_options, :name, :xandra)

        children = [
          # Ensure the :astarte_data_access process is started
          {Xandra.Cluster, ae_xandra_opts},
          {Astarte.DataAccess, data_access_opts}
        ]

        opts = [strategy: :one_for_one, name: AstarteImport.Supervisor]
        Supervisor.start_link(children, opts)

        opts_host_and_port = [db_host_and_port: db_host_and_port]
        CLI.main(realm, file_name, opts_host_and_port)

      _ ->
        Logger.info("Usage: mix astarte.import <realm> <file_name>")
    end
  end
end
