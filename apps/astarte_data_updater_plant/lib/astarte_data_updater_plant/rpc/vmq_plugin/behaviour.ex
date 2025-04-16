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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.RPC.VMQPlugin.Behaviour do
  @moduledoc false

  @callback publish(data :: %{topic_tokens: list(binary()), payload: binary(), qos: 0 | 1 | 2}) ::
              :ok
              | {:ok, %{local_matches: integer(), remote_matches: integer()}}
              | {:error, term()}

  @callback delete(data :: %{realm_name: binary(), device_id: binary()}) :: :ok | {:error, term()}

  @callback disconnect(data :: %{client_id: binary(), discard_state: boolean()}) ::
              :ok | {:error, term()}
end
