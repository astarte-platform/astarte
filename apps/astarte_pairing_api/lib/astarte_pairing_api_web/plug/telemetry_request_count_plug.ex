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
#

defmodule Astarte.Pairing.APIWeb.Plug.Telemetry.RequestCount do
  def init(_opts) do
    nil
  end

  def call(conn, _opts) do
    # The computation of request_size can take a non-negligible amount of time
    # in the API request/response cycle, so we run it in another process.
    Task.start(fn ->
      :telemetry.execute(
        [:astarte, :pairing, :api, :requests],
        %{
          bytes: request_size(conn.params)
        },
        %{
          realm: conn.params["realm_name"]
        }
      )
    end)

    conn
  end

  defp request_size(request) when is_map(request) do
    Enum.reduce(request, 0, fn {k, v}, acc -> acc + byte_size(k) + request_size(v) end)
  end

  defp request_size(request) do
    byte_size(request)
  end
end
