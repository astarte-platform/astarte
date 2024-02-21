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

defmodule Astarte.Housekeeping.APIWeb.Plug.Telemetry.ResponseCount do
  import Plug.Conn

  def init(_opts) do
    nil
  end

  def call(conn, _default) do
    register_before_send(conn, fn conn ->
      :telemetry.execute(
        [:astarte, :housekeeping, :api, :responses],
        %{
          bytes: IO.iodata_length(conn.resp_body)
        },
        %{}
      )

      conn
    end)
  end
end
