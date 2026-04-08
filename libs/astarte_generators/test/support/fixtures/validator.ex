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

defmodule Astarte.Support.Fixtures.Validator do
  @moduledoc """
  Fixtures for validating generators
  """
  alias Astarte.Support.Helpers.Validator, as: ValidatorHelper

  @spec changeset_validate(%{:validation_module => module(), optional(any()) => any()}) ::
          {:ok, [{any(), any()}, ...]}
  def changeset_validate(%{validation_module: validation_module}) do
    {:ok,
     changeset_validate: fn struct ->
       ValidatorHelper.changeset_validate(validation_module, struct)
     end}
  end
end
