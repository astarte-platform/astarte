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

defmodule Astarte.Housekeeping.ApiWeb.VersionControllerTest do
  use Astarte.Housekeeping.APIWeb.ConnCase
  use Astarte.Housekeeping.APIWeb.AuthCase

  test "returns a 200 status code", %{conn: conn} do
    expected_version = Mix.Project.config()[:version]
    conn = get(conn, "/v1/version")

    assert json_response(conn, 200) == %{
             "data" => expected_version
           }
  end
end
