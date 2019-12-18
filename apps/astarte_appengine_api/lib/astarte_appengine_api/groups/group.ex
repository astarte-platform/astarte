#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.AppEngine.API.Groups.Group

  embedded_schema do
    field :devices, {:array, :string}
    field :group_name, :string
  end

  @doc false
  def changeset(%Group{} = group, attrs) do
    group
    |> cast(attrs, [:group_name, :devices])
    |> validate_required([:group_name, :devices])
    |> validate_length(:devices, min: 1)
    |> validate_change(:group_name, &group_name_validator/2)
  end

  defp group_name_validator(field, group_name) do
    if Astarte.Core.Group.valid_name?(group_name) do
      []
    else
      [{field, "is not valid"}]
    end
  end
end
