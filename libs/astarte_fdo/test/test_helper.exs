#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

Mimic.copy(:hackney)
Mimic.copy(Astarte.DataAccess.Config)
Mimic.copy(Astarte.FDO.Config)

# Define a test endpoint module for FDO session tokens
defmodule Astarte.FDO.TestEndpoint do
  def config(:secret_key_base), do: "test_secret_key_for_fdo_sessions_in_tests"
end

Application.put_env(:astarte_fdo, :endpoint, Astarte.FDO.TestEndpoint)
Application.put_env(:astarte_fdo, :base_url_domain, "api.astarte.localhost")
Application.put_env(:astarte_fdo, :base_url_port, 4003)
Application.put_env(:astarte_fdo, :base_url_protocol, :http)

Mimic.copy(Astarte.DataAccess.Health.Health)
Mimic.copy(Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfo)
Mimic.copy(Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfoReady)
Mimic.copy(Astarte.FDO.Core.OwnerOnboarding.ProveDevice)
Mimic.copy(Astarte.FDO.Core.OwnerOnboarding.Session)
Mimic.copy(Astarte.FDO.Core.OwnershipVoucher.Core)
Mimic.copy(Astarte.FDO.OwnerOnboarding.DeviceAttestation)
Mimic.copy(Astarte.FDO.OwnerOnboarding)
Mimic.copy(Astarte.FDO.Rendezvous.Client)
Mimic.copy(Astarte.FDO.Rendezvous)
Mimic.copy(Astarte.FDO.ServiceInfo)
Mimic.copy(Astarte.Secrets)
Mimic.copy(DateTime)
Mimic.copy(HTTPoison)

ExUnit.start(capture_log: true)
