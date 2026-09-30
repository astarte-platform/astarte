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

defmodule Astarte.FDO.Config.BaseURLHostTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Config.BaseURLHost

  describe "cast/1" do
    test "casts a domain name to a :domain struct" do
      assert BaseURLHost.cast("astarte.example.com") ==
               {:ok, %BaseURLHost{type: :domain, value: "astarte.example.com"}}
    end

    test "casts an IPv4 address to an :ip struct" do
      assert BaseURLHost.cast("192.168.1.10") ==
               {:ok, %BaseURLHost{type: :ip, value: {192, 168, 1, 10}}}
    end

    test "casts an IPv6 address to an :ip struct" do
      assert BaseURLHost.cast("::1") ==
               {:ok, %BaseURLHost{type: :ip, value: {0, 0, 0, 0, 0, 0, 0, 1}}}
    end

    test "accepts tuples" do
      assert BaseURLHost.cast({:domain, "astarte.example.com"}) ==
               {:ok, %BaseURLHost{type: :domain, value: "astarte.example.com"}}

      assert BaseURLHost.cast({:ip, {192, 168, 1, 10}}) ==
               {:ok, %BaseURLHost{type: :ip, value: {192, 168, 1, 10}}}
    end

    test "accepts itself" do
      {:ok, base_url_host} = BaseURLHost.cast("astarte.example.com")
      assert BaseURLHost.cast(base_url_host) == {:ok, base_url_host}
    end

    test "returns error for a blank or non-binary value" do
      assert BaseURLHost.cast("") == :error
      assert BaseURLHost.cast(nil) == :error
      assert BaseURLHost.cast(1234) == :error
    end
  end

  describe "String.Chars" do
    test "returns a domain name unchanged" do
      assert to_string(%BaseURLHost{type: :domain, value: "astarte.example.com"}) ==
               "astarte.example.com"
    end

    test "renders an IPv4 address" do
      assert to_string(%BaseURLHost{type: :ip, value: {192, 168, 1, 10}}) == "192.168.1.10"
    end

    test "renders an IPv6 address" do
      assert to_string(%BaseURLHost{type: :ip, value: {0, 0, 0, 0, 0, 0, 0, 1}}) == "::1"
    end

    test "round-trips a cast value" do
      for value <- ["astarte.example.com", "192.168.1.10", "::1"] do
        assert {:ok, host} = BaseURLHost.cast(value)
        assert to_string(host) == value
      end
    end
  end
end
