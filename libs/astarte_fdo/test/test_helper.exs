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

# Define a test endpoint module for FDO session tokens
defmodule Astarte.FDO.TestEndpoint do
  def config(:secret_key_base), do: "test_secret_key_for_fdo_sessions_in_tests"
end

Application.put_env(:astarte_fdo, :endpoint, Astarte.FDO.TestEndpoint)
Application.put_env(:astarte_fdo, :base_url_domain, "api.astarte.localhost")
Application.put_env(:astarte_fdo, :base_url_port, 4003)
Application.put_env(:astarte_fdo, :base_url_protocol, :http)

modules = [
  :hackney,
  Astarte.DataAccess.Config,
  Astarte.FDO.Config,
  Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfo,
  Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfoReady,
  Astarte.FDO.Core.OwnerOnboarding.ProveDevice,
  Astarte.FDO.Core.OwnershipVoucher.Core,
  Astarte.FDO.OwnerOnboarding,
  Astarte.FDO.OwnerOnboarding.DeviceAttestation,
  Astarte.FDO.OwnerOnboarding.Session,
  Astarte.FDO.Rendezvous,
  Astarte.FDO.Rendezvous.Client,
  Astarte.FDO.ServiceInfo,
  Astarte.RPC.RealmManagement,
  Astarte.Secrets,
  DateTime,
  HTTPoison
]

for module <- modules, do: Mimic.copy(module)

# fix flakiness caused by namespaces being created at the same time
Astarte.Secrets.Core.create_nested_namespace(["fdo_owner_keys", "instance"])

ExUnit.start(capture_log: true)
