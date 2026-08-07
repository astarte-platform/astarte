#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.FDO.ConfigTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Astarte.FDO.Config
  alias Astarte.FDO.Config.BaseURLProtocol

  describe "BaseURLProtocol.cast/1" do
    test "casts valid string protocols" do
      for proto <- ["tcp", "tls", "http", "coap", "https", "coaps"] do
        assert {:ok, String.to_atom(proto)} == BaseURLProtocol.cast(proto)
      end
    end

    test "accepts already-atom protocols" do
      for proto <- [:tcp, :tls, :http, :coap, :https, :coaps] do
        assert {:ok, proto} == BaseURLProtocol.cast(proto)
      end
    end

    test "returns error for unknown string" do
      assert :error == BaseURLProtocol.cast("ftp")
    end

    test "returns error for unrecognised value" do
      assert :error == BaseURLProtocol.cast(1234)
    end
  end

  describe "base_url!/0" do
    test "builds the URL from protocol, domain and port" do
      stub(Config, :base_url_protocol!, fn -> :https end)
      stub(Config, :base_url_domain!, fn -> "astarte.example.com" end)
      stub(Config, :base_url_port!, fn -> 443 end)

      assert Config.base_url!() == "https://astarte.example.com:443"
    end
  end
end
