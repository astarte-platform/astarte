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

defmodule Astarte.FDO.SessionKey do
  @moduledoc """
  Ecto embedded schema representing the `session_key` Cassandra UDT.

  Fields map to `%COSE.Keys.Symmetric{}`:

    - `alg` — cipher algorithm atom stored as text (e.g. `"aes_128_gcm"`)
    - `k`   — raw binary key material
    - `kty` — key type atom stored as text

  Conversion to/from `%COSE.Keys.Symmetric{}` is handled by
  `Astarte.FDO.OwnerOnboarding.SessionKey.to_db/1` and `from_db/1`.
  """

  use TypedEctoSchema

  @primary_key false
  typed_embedded_schema do
    field :alg, :string
    field :k, :binary
    field :kty, :string
  end
end
