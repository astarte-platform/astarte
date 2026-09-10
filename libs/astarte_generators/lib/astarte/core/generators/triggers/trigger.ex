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

defmodule Astarte.Core.Generators.Triggers.Trigger do
  @moduledoc """
  Generates Astarte trigger protobufs with valid HTTP actions.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Common.Generators.HTTP
  import Astarte.Common.Generators.UUID

  alias Astarte.Core.Triggers.Trigger

  @http_methods ~w(delete get head options patch post put)

  @doc """
  Generates an Astarte trigger.

  Correlated simple trigger identifiers and an installed policy name can be supplied through the
  `simple_triggers_uuids` and `policy` parameters when preparing seeded data.
  """
  @spec trigger() :: StreamData.t(Trigger.t())
  @spec trigger(params :: keyword()) :: StreamData.t(Trigger.t())
  def trigger(params \\ []) do
    params gen all version <- constant(0),
                   trigger_uuid <- uuid(),
                   simple_triggers_uuids <- list_of(uuid(), min_length: 1, max_length: 8),
                   action <- action(),
                   name <- name(),
                   policy <- constant(nil),
                   params: params do
      %Trigger{
        version: version,
        trigger_uuid: trigger_uuid,
        simple_triggers_uuids: simple_triggers_uuids,
        action: action,
        name: name,
        policy: policy
      }
    end
  end

  defp action do
    gen all http_url <- http_url(),
            http_method <- member_of(@http_methods),
            http_static_headers <- http_static_headers(),
            ignore_ssl_errors <- boolean() do
      Jason.encode!(%{
        "http_url" => http_url,
        "http_method" => http_method,
        "http_static_headers" => http_static_headers,
        "ignore_ssl_errors" => ignore_ssl_errors
      })
    end
  end

  defp http_static_headers,
    do: map_of(http_header_name(), string(:alphanumeric, max_length: 64), max_length: 8)

  defp http_header_name,
    do: string(:alphanumeric, min_length: 1, max_length: 32) |> map(&"x-astarte-#{&1}")

  defp name, do: string(:alphanumeric, min_length: 1, max_length: 128)
end
