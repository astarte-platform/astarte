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

defmodule Astarte.Core.Adapters.Triggers.Policy do
  @moduledoc """
  Trasformings from Astarte.Core.Adapters.Triggers.Policy
  """
  use Astarte.Adapters

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange

  transform from_core_triggers_policy_to_change do
    @source Policy.t()
    @returns map()

    keep :name, :maximum_capacity
    field :retry_times <- :retry_times, required: false
    field :event_ttl <- :event_ttl, required: false
    field :prefetch_count <- :prefetch_count, required: false
    field :error_handlers <- :error_handlers, &error_handlers/2
  end

  transformp error_handler do
    keep :strategy
    field :on <- :on, &on/2
  end

  transformp error_type do
    pre_process &error_type_pre_process/1
    keep :error, :format
    post_process &error_type_post_process/1
  end

  transformp error_range do
    field "error_codes" <- :error_codes
  end

  transformp error_keyword do
    field "keyword" <- :keyword
  end

  defp error_handlers(error_handlers, _source),
    do: Enum.map(error_handlers, &error_handler(&1))

  defp on(on, _source), do: error_type(on)

  defp error_type_pre_process(source), do: %{error: source, format: Enum.random([:raw, :map])}

  defp error_type_post_process(%{error: %ErrorKeyword{} = error, format: :map}),
    do: error_keyword(error)

  defp error_type_post_process(%{error: %ErrorRange{} = error, format: :map}),
    do: error_range(error)

  defp error_type_post_process(%{error: %ErrorKeyword{keyword: keyword}, format: :raw}),
    do: keyword

  defp error_type_post_process(%{error: %ErrorRange{error_codes: error_codes}, format: :raw}),
    do: error_codes
end
