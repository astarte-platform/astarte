defmodule Astarte.ExportTest do
  use ExUnit.Case
  alias Astarte.Export

  @realm "test"


  test "Test export from Cassandra database" do
    path = System.cwd <> "/" <> #{realm} <> "_" <> Export.format_time <> ".xml"
    assert Export.export_relam_data(@realm, path) == :ok
  end
end
