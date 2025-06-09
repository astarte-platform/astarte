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

Mimic.copy(Astarte.Core.Mapping.ValueType)
Mimic.copy(Astarte.DataAccess.Config)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Server)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Core.Device)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandler)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Core.Error)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.Core.Interface)
Mimic.copy(Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder)
Mimic.copy(Astarte.DataUpdaterPlant.MessageTracker)
Mimic.copy(Astarte.DataUpdaterPlant.RPC.Server.Core)
Mimic.copy(Astarte.DataUpdaterPlant.RPC.VMQPlugin)
Mimic.copy(System)
Mimic.copy(Xandra)
Mimic.copy(Astarte.DataAccess.Health.Health)

ExUnit.start(capture_log: true)
