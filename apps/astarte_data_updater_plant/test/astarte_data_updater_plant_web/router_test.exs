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

defmodule Astarte.DataUpdaterPlantWeb.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Astarte.DataUpdaterPlantWeb.Router

  test "returns 404 for unknown route" do
    conn = conn(:get, "/unknown") |> Router.call([])
    assert conn.status == 404
    assert conn.resp_body == "Not found"
  end
end
