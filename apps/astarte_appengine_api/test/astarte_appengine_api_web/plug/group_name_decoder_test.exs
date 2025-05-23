#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.AppEngine.APIWeb.Plug.GroupNameDecoderTest do
  use Astarte.AppEngine.APIWeb.ConnCase
  use ExUnitProperties
  alias Astarte.AppEngine.APIWeb.Plug.GroupNameDecoder
  alias Astarte.AppEngine.API.GroupTestGenerator

  @max_subpath_count 10

  @tag issue: 904
  property "call/2 decode path" do
    check all raw <- GroupTestGenerator.group_name() do
      conn = build_conn()
      # Normally, phx does encoding
      encoded =
        raw
        |> URI.encode()

      request =
        put_in(
          conn.path_params["group_name"],
          encoded
        )

      %{path_params: %{"group_name" => check}} =
        request
        |> GroupNameDecoder.call(nil)

      assert check == raw,
             "The group name #{encoded} cannot be decoded back to its original value"
    end
  end
end
