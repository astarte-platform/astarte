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

defmodule Astarte.Auth.Cases.AuthorizationModel do
  @moduledoc """
  Gives the test module a store of its own on the OpenFGA server, holding
  Astarte's authorization model, and points `Astarte.Auth.OpenFGA` at it.

  The model is `priv/authorization_model.json`, which CI checks is up to date
  with `priv/authorization_model.fga`. The context holds the `:store_id`, to
  write the module's tuples to with
  `Astarte.Auth.Helpers.OpenFGA.write_tuples!/2`.
  """

  use ExUnit.CaseTemplate
  use Mimic

  import Astarte.Auth.Helpers.OpenFGA

  alias Astarte.Auth.Config

  using do
    quote do
      import Astarte.Auth.Helpers.OpenFGA
    end
  end

  setup_all do
    store_id = create_store!(unique_store_name())

    model =
      :astarte_auth
      |> :code.priv_dir()
      |> Path.join("authorization_model.json")
      |> File.read!()
      |> Jason.decode!()

    write_model!(store_id, model)

    %{store_id: store_id}
  end

  setup %{store_id: store_id} do
    stub(Config, :openfga_store_id!, fn -> store_id end)
    :ok
  end
end
