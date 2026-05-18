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

defmodule Astarte.AppEngine.APIWeb.Plug.SwaggerUI do
  @moduledoc "Swagger UI plug that serves the OpenAPI specification documentation for the Astarte AppEngine API."
  @behaviour Plug

  alias OpenApiSpex.Plug.SwaggerUI

  import Plug.Conn, only: [get_req_header: 2]

  def init(opts) do
    SwaggerUI.init(opts)
  end

  def call(conn, opts) do
    opts = put_forwarded_spec_path(opts, conn)

    SwaggerUI.call(conn, opts)
  end

  defp put_forwarded_spec_path(opts, conn) do
    Map.update!(opts, :path, &(spec_path(conn) <> &1))
  end

  defp spec_path(conn) do
    get_req_header(conn, "x-forwarded-prefix")
    |> List.first("")
  end
end
