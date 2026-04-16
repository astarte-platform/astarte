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

defmodule Astarte.FDO.Core.Rendezvous.RvTO2AddrTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr

  describe "encode_protocol/1" do
    test "encodes all supported protocols" do
      assert RvTO2Addr.encode_protocol(:tcp) == 1
      assert RvTO2Addr.encode_protocol(:tls) == 2
      assert RvTO2Addr.encode_protocol(:http) == 3
      assert RvTO2Addr.encode_protocol(:coap) == 4
      assert RvTO2Addr.encode_protocol(:https) == 5
      assert RvTO2Addr.encode_protocol(:coaps) == 6
    end

    test "raises for unknown protocol" do
      assert_raise KeyError, fn -> RvTO2Addr.encode_protocol(:ftp) end
    end
  end
end
