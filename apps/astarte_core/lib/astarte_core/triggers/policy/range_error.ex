#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind srl
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

defmodule Astarte.Core.Triggers.Policy.ErrorRange do
  @moduledoc """
  Defines the schema and changeset for HTTP error ranges used in trigger policies.
  """

  use TypedEctoSchema
  import Ecto.Changeset

  @error_range 400..599

  @derive Jason.Encoder
  @primary_key false
  typed_embedded_schema do
    field :error_codes, {:array, :integer}
  end

  def validate(changeset) do
    changeset
    |> validate_subset(:error_codes, @error_range,
      message: "Must be an HTTP error code between 400 and 599"
    )
    |> validate_length(:error_codes, min: 1)
  end
end
