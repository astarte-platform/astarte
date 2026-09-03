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
#

defmodule Astarte.FDO.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Astarte.Config

  alias Astarte.FDO.Config.BaseURLIp
  alias Astarte.FDO.Config.BaseURLProtocol

  @envdoc "The port the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_port, :astarte_fdo, :base_url_port,
    os_env: "ASTARTE_BASE_URL_PORT",
    type: :integer,
    required: true

  @envdoc "The protocol the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_protocol, :astarte_fdo, :base_url_protocol,
    os_env: "ASTARTE_BASE_URL_PROTOCOL",
    type: BaseURLProtocol,
    required: true

  @envdoc """
  The astarte base domain, used for FDO authentication mechanism. At least
  one between this and `base_url_ip` must be configured; when both are set,
  devices are given preference for the domain over the IP address.
  """
  app_env :base_url_domain, :astarte_fdo, :base_url_domain,
    os_env: "ASTARTE_BASE_URL_DOMAIN",
    type: :binary

  @envdoc """
  The astarte base IP address, used for FDO authentication mechanism as an
  alternative to `base_url_domain` (e.g. when no DNS resolution is available
  to the device). At least one between this and `base_url_domain` must be
  configured.
  """
  app_env :base_url_ip, :astarte_fdo, :base_url_ip,
    os_env: "ASTARTE_BASE_URL_IP",
    type: BaseURLIp

  url_env :rendezvous, :astarte_fdo, :rendezvous, env_app: "PAIRING_FDO", default_port: 8041

  @envdoc "Endpoint module to use for FDO session tokens (must have secret_key_base configured)"
  app_env :fdo_session_endpoint, :astarte_fdo, :endpoint,
    os_env: "FDO_SESSION_ENDPOINT",
    type: :atom

  def init! do
    # check that all mandatory FDO variables are configured before starting
    __MODULE__.validate!()
    validate_base_url_host!()
  end

  def base_url! do
    protocol = __MODULE__.base_url_protocol!()
    host = __MODULE__.base_url_host!()
    port = __MODULE__.base_url_port!()

    "#{protocol}://#{host}:#{port}"
  end

  @doc """
  Returns the preferred host to reach Astarte (a blank string counts as
  unconfigured, same as nil).
  """
  def base_url_host! do
    [__MODULE__.base_url_domain!(), __MODULE__.base_url_ip!()]
    |> Enum.find(&(&1 not in [nil, ""]))
  end

  defp validate_base_url_host! do
    if is_nil(__MODULE__.base_url_host!()) do
      raise "At least one of ASTARTE_BASE_URL_DOMAIN or ASTARTE_BASE_URL_IP must be configured"
    end

    :ok
  end
end
