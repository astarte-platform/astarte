defmodule Astarte.Config.HTTPClientTest do
  use ExUnit.Case
  use ExUnitProperties

  defmodule SampleClient do
    @moduledoc false

    use Astarte.Config.HTTPClient, config: SampleConfig, service: :my_service
  end

  describe "generated process_request_url/1" do
    test "prepends the base URL to the given path" do
      base_url = SampleConfig.my_service_url!()
      path = "/some_path"

      result = SampleClient.process_request_url(path)

      assert result == base_url <> path
    end
  end

  describe "generated process_request_options/1" do
    test "performs deep merges of opts" do
      SampleConfig.put_my_service_ssl_enabled(true)
      SampleConfig.reload_my_service_request_opts()
      result = SampleClient.process_request_options(ssl: [some: :key])
      assert result[:ssl][:some] == :key
      assert result[:ssl][:verify] == :verify_peer
    end

    test "gives priority to user-defined options" do
      SampleConfig.put_my_service_ssl_enabled(true)
      SampleConfig.reload_my_service_request_opts()
      result = SampleClient.process_request_options(ssl: [verify: :verify_none])
      assert result[:ssl][:verify] == :verify_none
    end
  end
end
