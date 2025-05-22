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

defmodule Astarte.AppEngine.APIWeb.Plug.GroupNameDecoder do
  @moduledoc """
  This plug decodes a group name, which may have been encoded
  to remove the forward slash
  """
  def init(default), do: default

  def call(%Plug.Conn{path_params: %{"group_name" => group_name}} = conn, _) do
    put_in(conn.path_params["group_name"], URI.decode(group_name))
  end

  def call(conn, _), do: conn
end
