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

defmodule Astarte.Pairing.FDO.Rendezvous.Client do
  require Logger

  use HTTPoison.Base

  alias Astarte.Pairing.Config

  @impl true
  def process_request_url(url) do
    Config.fdo_rendezvous_url!() <> url
  end

  @impl true
  def process_request_options(options) do
    auth_opts = [
      # ssl: Config.ssl_options!() no ssl?
    ]

    Keyword.merge(auth_opts, options)
  end

  @impl true
  def process_response_headers(headers) do
    Enum.map(headers, fn
      {key, value} ->
        {String.downcase(key), value}
    end)
  end
end
