#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Support.Helpers.Validator do
  @moduledoc """
  Helpers functions for validating generators
  """
  alias Ecto.Changeset

  @spec changeset_validate(module(), struct()) :: Ecto.Changeset.t()
  def changeset_validate(module, struct) do
    changes = Map.from_struct(struct)

    struct
    |> Changeset.change(changes)
    |> module.validate()
  end
end
