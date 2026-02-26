#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Credentials.AstarteMQTTV1.Credentials do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Astarte.Pairing.Credentials.AstarteMQTTV1.Credentials

  @primary_key false
  embedded_schema do
    field :client_crt, :string
  end

  @doc false
  def changeset(%Credentials{} = verify_request, attrs) do
    verify_request
    |> cast(attrs, [:client_crt])
    |> validate_required([:client_crt])
  end
end
