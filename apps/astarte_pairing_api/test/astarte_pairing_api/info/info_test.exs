defmodule Astarte.Pairing.API.InfoTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Info.BrokerInfo
  alias Astarte.Pairing.API.Info
  alias Astarte.Pairing.Mock

  describe "broker_info" do
    test "get_broker_info! returns valid broker_info with given id" do
      assert %BrokerInfo{url: url, version: version} = Info.get_broker_info!()
      assert url == Mock.broker_url()
      assert version == Mock.version()
    end
  end
end
