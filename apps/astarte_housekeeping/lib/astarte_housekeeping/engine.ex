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

defmodule Astarte.Housekeeping.Engine do
  require Logger

  alias Astarte.Housekeeping.Queries

  def create_realm(
        realm,
        public_key_pem,
        replication_factor,
        device_registration_limit,
        max_retention,
        opts \\ []
      ) do
    _ =
      Logger.info(
        "Creating new realm.",
        tag: "create_realm",
        realm: realm,
        replication_factor: replication_factor,
        device_registration_limit: device_registration_limit,
        datastream_maximum_storage_retention: max_retention
      )

    Queries.create_realm(
      realm,
      public_key_pem,
      replication_factor,
      device_registration_limit,
      max_retention,
      opts
    )
  end

  def is_realm_existing(realm) do
    Queries.is_realm_existing(realm)
  end
end
