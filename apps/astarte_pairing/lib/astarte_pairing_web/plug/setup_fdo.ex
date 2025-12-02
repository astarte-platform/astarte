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

defmodule Astarte.PairingWeb.Plug.SetupFDO do
  use Plug.Builder

  alias Astarte.PairingWeb.FDOFallbackController

  import Plug.Conn

  def init(_opts) do
    nil
  end

  def call(conn, _opts) do
    # all fdo messages are /fdo/101/msg/id
    {:ok, message_id} = parse_message_id(conn.request_path)

    # we always return the following message, except for errors (in which case we override)
    next_message_id = message_id + 1

    case read_body(conn) do
      {:ok, body, conn} ->
        conn
        |> put_resp_header("message-type", to_string(next_message_id))
        |> assign(:message_id, message_id)
        |> assign(:cbor_body, body)

      _ ->
        FDOFallbackController.message_body_error(conn)
    end
  end

  defp parse_message_id(path) do
    path
    |> String.split("/")
    |> List.last("")
    |> Integer.parse()
    |> case do
      {message_id, _} -> {:ok, message_id}
      :error -> :error
    end
  end
end
