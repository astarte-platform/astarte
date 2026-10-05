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

modules = [
  Astarte.DataAccess.Config,
  Astarte.DataAccess.Database,
  Astarte.DataAccess.Health,
  Astarte.DataAccess.KvStore,
  Astarte.DataAccess.Realms.Realm,
  Astarte.DataAccess.Repo,
  Astarte.Events.AMQP,
  Astarte.Events.AMQP.Vhost,
  Astarte.Events.Config,
  Astarte.Housekeeping.Config,
  Astarte.Housekeeping.Health,
  Astarte.Housekeeping.Migrator,
  Astarte.Housekeeping.Realms,
  Astarte.Housekeeping.Realms.Queries,
  Astarte.Secrets,
  HTTPoison,
  HTTPoison.Base,
  Xandra
]

for module <- modules, do: Mimic.copy(module)

ExUnit.start(capture_log: true)
