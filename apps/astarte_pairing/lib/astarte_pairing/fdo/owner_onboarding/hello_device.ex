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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice do
  @moduledoc """
  HelloDevice structure as per FDO specification.
  """
  use TypedStruct

  @type sign_info :: {String.t(), binary()}

  typedstruct enforce: true do
    @typedoc "A hello device message structure."

    field :max_size, non_neg_integer()
    field :device_id, binary()
    field :nonce, binary()
    field :kex_name, String.t()
    field :cipher_name, String.t()
    field :easig_info, sign_info()
  end
end
