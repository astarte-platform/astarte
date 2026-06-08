#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind srl
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

defmodule Astarte.Events.AMQP do
  use HTTPoison.Base

  @moduledoc """
  Module providing basic HTTP functionalities to interact with the AMQP management API.
  """
  alias Astarte.Events.Config

  @impl true
  def process_request_url(url) do
    Config.amqp_management_base_url!() <> url
  end

  @impl true
  def process_request_options(options) do
    auth_opts = [
      hackney: [
        basic_auth: {Config.amqp_management_username!(), Config.amqp_management_password!()}
      ],
      ssl: Config.ssl_management_options!()
    ]

    Keyword.merge(auth_opts, options)
  end
end
