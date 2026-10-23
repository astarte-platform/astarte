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

defmodule Astarte.Auth.Config do
  @moduledoc """
  Configuration of the authorization services shared by every Astarte service.

  OpenFGA is a single cluster-wide deployment, so it is configured here once
  instead of once per service: every service reads the same `ASTARTE_OPENFGA_*`
  environment variables.
  """

  use Astarte.Config, env_app: "ASTARTE"

  url_env :openfga, :astarte_auth, :openfga, default_port: 8080, env_app: "ASTARTE"

  @envdoc "The OpenFGA store id to use for authorization checks."
  app_env :openfga_store_id, :astarte_auth, :openfga_store_id,
    os_env: "ASTARTE_OPENFGA_STORE_ID",
    type: :binary,
    required: true
end
