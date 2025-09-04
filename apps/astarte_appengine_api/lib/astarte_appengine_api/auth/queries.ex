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

defmodule Astarte.AppEngine.API.Auth.Queries do
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Consistency

  import Ecto.Query

  require Logger

  def fetch_public_key(realm_name) do
    keyspace_name = Realm.keyspace_name(realm_name)

    schema_query =
      from r in KvStore,
        prefix: ^keyspace_name,
        select: fragment("blobAsVarchar(?)", r.value),
        where: r.group == "auth" and r.key == "jwt_public_key_pem"

    opts = [
      uuid_format: :binary,
      consistency: Consistency.domain_model(:read),
      error: :public_key_not_found
    ]

    Repo.safe_fetch_one(schema_query, opts)
  end
end
