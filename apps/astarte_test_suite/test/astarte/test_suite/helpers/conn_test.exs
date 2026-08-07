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

defmodule Astarte.TestSuite.Helpers.ConnTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Helpers.Conn, as: ConnHelper

  test "conn setup helper raises not implemented" do
    assert_raise RuntimeError, "not implemented yet", fn ->
      ConnHelper.setup(%{instance_database_ready?: true})
    end
  end

  test "conn data helper raises not implemented" do
    assert_raise RuntimeError, "not implemented yet", fn ->
      ConnHelper.data(%{instance_database_ready?: true})
    end
  end
end
