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

defmodule Astarte.Helpers.Key do
  @moduledoc false

  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  def key_setup(context) do
    realm_name = "realm#{System.unique_integer([:positive])}"
    key_name = "key#{System.unique_integer()}"
    key_algorithm = Map.get(context, :key_algorithm, :es256)
    {:ok, namespace} = Secrets.create_fdo_namespace(realm_name, key_algorithm)
    {:ok, data} = Secrets.create_keypair(key_name, key_algorithm, namespace: namespace)
    {:ok, key} = Key.parse(key_name, namespace, data)

    %{key: key}
  end
end
