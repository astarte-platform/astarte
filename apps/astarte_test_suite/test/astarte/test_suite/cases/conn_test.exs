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

defmodule Astarte.TestSuite.Cases.ConnTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  alias Astarte.TestSuite.Cases.Conn, as: ConnCase

  test "requires conn configuration" do
    assert_raise ArgumentError, ~r/:conn requires :conn to be configured/, fn ->
      ConnCase.normalize_config!([])
    end
  end

  test "normalizes conn configuration" do
    assert ConnCase.normalize_config!(conn: %Conn{}) == %{
             conn: %Conn{}
           }
  end

  test "keeps an explicit nil conn configuration" do
    assert ConnCase.normalize_config!(conn: nil) == %{conn: nil}
  end

  test "rejects invalid conn configuration" do
    assert_raise ArgumentError, ~r/expects :conn to be a Plug.Conn struct/, fn ->
      ConnCase.normalize_config!(conn: %{})
    end
  end

  test "rejects a struct of the wrong type" do
    assert_raise ArgumentError, ~r/expects :conn to be a Plug.Conn struct/, fn ->
      ConnCase.normalize_config!(conn: %URI{})
    end
  end
end
