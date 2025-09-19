#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

Mimic.copy(Astarte.DataAccess.Config)
Mimic.copy(Astarte.DataAccess.Health.Health)
Mimic.copy(Astarte.DataAccess.KvStore)
Mimic.copy(Astarte.DataAccess.Repo)
Mimic.copy(Astarte.RealmManagement.RealmConfig.Queries)
Mimic.copy(Astarte.DataAccess.Config)
Mimic.copy(Astarte.RealmManagement.Devices.Queries)
Mimic.copy(Task)
ExUnit.start(capture_log: true)
