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

defmodule Astarte.DataAccess.FDO.TO2Session do
  use TypedEctoSchema

  @primary_key false
  typed_schema "to2_sessions" do
    field :session_key, :binary, primary_key: true
    field :device_id, Astarte.DataAccess.UUID
    field :sig_type, Ecto.Enum, values: [es256: -7, es384: -35, eipd10: 90, eipd11: 91]
    field :epid_group, :binary
    field :device_public_key, :binary
    field :prove_dv_nonce, :binary
    field :kex_suite_name, :string
    field :cipher_suite_name, :string
    field :owner_random, :binary
    field :secret, :binary
    field :sevk, :binary
    field :svk, :binary
    field :sek, :binary
  end
end
