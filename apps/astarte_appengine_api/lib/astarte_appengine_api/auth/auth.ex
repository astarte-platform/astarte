#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Auth do
  alias Astarte.AppEngine.API.Queries
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.CQLUtils

  require Logger

  def fetch_public_key(realm) do
    keyspace = CQLUtils.realm_name_to_keyspace_name(realm, Config.astarte_instance_id!())

    Queries.fetch_public_key(keyspace)
  end
end
