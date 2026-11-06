#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.AppEngine.APIWeb.GraphQL.Schema do
  @moduledoc """
  The GraphQL schema of Astarte AppEngine API.

  Every root field is authorized through OpenFGA and is nullable, so that a
  field the caller can't access doesn't take the rest of the response with it.
  """

  use Absinthe.Schema

  alias Astarte.AppEngine.APIWeb.GraphQL.Resolvers.DeviceResolver
  alias Astarte.AppEngine.APIWeb.GraphQL.Resolvers.StatsResolver
  alias Astarte.Auth.GraphQL.Middleware.AuthorizeFGA
  alias Astarte.Auth.GraphQL.Middleware.HandleErrors

  import_types Absinthe.Type.Custom
  import_types Astarte.AppEngine.APIWeb.GraphQL.Types.DeviceTypes
  import_types Astarte.AppEngine.APIWeb.GraphQL.Types.StatsTypes

  @impl Absinthe.Schema
  def middleware(middleware, _field, %{identifier: identifier})
      when identifier in [:query, :mutation],
      do: middleware ++ [HandleErrors]

  def middleware(middleware, _field, _object), do: middleware

  query do
    @desc "A device of the realm"
    field :device, :device do
      arg :device_id, non_null(:string)

      middleware AuthorizeFGA, relation: "can_read", target: {:device, :device_id}

      resolve &DeviceResolver.get_device/3
    end

    @desc "Device count statistics of the realm"
    field :devices_stats, :devices_stats do
      middleware AuthorizeFGA, relation: "can_read_stats", target: :realm

      resolve &StatsResolver.get_devices_stats/3
    end
  end
end
