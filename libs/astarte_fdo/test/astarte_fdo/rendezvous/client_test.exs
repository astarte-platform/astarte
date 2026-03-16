#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.FDO.Rendezvous.ClientTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Config
  alias Astarte.FDO.Rendezvous.Client

  describe "process_request_url/1" do
    test "prepends the configured rendezvous base URL to the given path" do
      base_url = Config.fdo_rendezvous_url!()
      path = "/fdo/101/msg/20"

      result = Client.process_request_url(path)

      assert result == base_url <> path
    end

    test "handles root path correctly" do
      base_url = Config.fdo_rendezvous_url!()
      result = Client.process_request_url("/")

      assert result == base_url <> "/"
    end
  end

  describe "process_response_headers/1" do
    test "lowercases all header keys" do
      headers = [{"Content-Type", "application/cbor"}, {"Authorization", "Bearer token"}]
      result = Client.process_response_headers(headers)

      assert {"content-type", "application/cbor"} in result
      assert {"authorization", "Bearer token"} in result
    end

    test "handles empty header list" do
      assert [] == Client.process_response_headers([])
    end
  end
end
