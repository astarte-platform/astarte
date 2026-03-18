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

defmodule Astarte.Helpers.OpenBao do
  @moduledoc false
  import Mimic

  alias Astarte.DataAccess.Config, as: DataAccessConfig

  def namespace_tokens_setup(context) do
    realm_name = "realm#{System.unique_integer([:positive])}"
    key_algorithm = [:ec256, :ec384, :rsa2048, :rsa3072] |> Enum.random()

    instance = Map.get(context, :instance, "")
    user_id = Map.get(context, :user_id, nil)

    stub(DataAccessConfig, :astarte_instance_id, fn -> {:ok, instance} end)
    stub(DataAccessConfig, :astarte_instance_id!, fn -> instance end)

    %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm, instance: instance}
  end
end
