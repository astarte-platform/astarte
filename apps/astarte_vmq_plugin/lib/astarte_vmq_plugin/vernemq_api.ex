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

defmodule Astarte.VMQ.Plugin.VerneMQ.API do
  @moduledoc "Real implementation of the VerneMQ API behaviour, delegating to :vernemq_dev_api."
  @behaviour Astarte.VMQ.Plugin.VerneMQ.API.Behaviour

  @impl true
  def disconnect_by_subscriber_id(subscriber_id, opts) do
    :vernemq_dev_api.disconnect_by_subscriber_id(subscriber_id, opts)
  catch
    :exit, :normal -> :ok
    :exit, {:normal, _} -> :ok
    :exit, :shutdown -> :ok
    :exit, {:shutdown, _} -> :ok
    :exit, :noproc -> :ok
    :exit, {:noproc, _} -> :ok
  end
end
