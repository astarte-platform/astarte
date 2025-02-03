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

defmodule Astarte.AppEngine.API.Queries do
  alias Astarte.DataAccess.Astarte.KvStore
  alias Astarte.DataAccess.Astarte.Realm

  import Ecto.Query

  def fetch_public_key(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from r in KvStore,
      prefix: ^keyspace,
      select: fragment("blobAsVarchar(?)", r.value),
      where: r.group == "auth" and r.key == "jwt_public_key_pem"
  end
end
