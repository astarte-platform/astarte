#
# This file is part of Astarte.
#
# Copyright 2017 - 2026 SECO Mind Srl
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

defmodule Astarte.FDO.Core.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.FDO.Core.Config.BaseURLProtocol

  @envdoc "The port the ingress is listening on, used for FDO authentication mechanism"
  app_env(:base_url_port, :astarte_pairing, :base_url_port,
    os_env: "ASTARTE_BASE_URL_PORT",
    type: :integer
  )

  @envdoc "The protocol the ingress is listening on, used for FDO authentication mechanism"
  app_env(:base_url_protocol, :astarte_pairing, :base_url_protocol,
    os_env: "ASTARTE_BASE_URL_PROTOCOL",
    type: BaseURLProtocol
  )

  @envdoc "The astarte base domain, used for FDO authentication mechanism"
  app_env(:base_url_domain, :astarte_pairing, :base_url_domain,
    os_env: "ASTARTE_BASE_URL_DOMAIN",
    type: :binary
  )

  @envdoc "The FDO Rendezvous Server URL"
  app_env(:fdo_rendezvous_url, :astarte_pairing, :fdo_rendezvous_url,
    os_env: "PAIRING_FDO_RENDEZVOUS_URL",
    type: :binary,
    default: "http://rendezvous:8041"
  )

  @envdoc "Endpoint module to use for FDO session tokens (must have secret_key_base configured)"
  app_env(:fdo_session_endpoint, :astarte_pairing, :fdo_session_endpoint,
    os_env: "FDO_SESSION_ENDPOINT",
    type: :atom
  )

  def base_url! do
    protocol = base_url_protocol!()
    domain = base_url_domain!()
    port = base_url_port!()

    "#{protocol}://#{domain}:#{port}"
  end
end
