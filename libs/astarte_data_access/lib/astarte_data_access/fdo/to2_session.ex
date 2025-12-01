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

  @ciphers [
    aes_128_gcm: 1,
    aes_192_gcm: 2,
    aes_256_gcm: 3,
    aes_ccm_16_64_128: 10,
    aes_ccm_16_64_256: 11,
    aes_ccm_64_64_128: 12,
    aes_ccm_64_64_256: 13,
    aes_ccm_16_128_128: 30,
    aes_ccm_16_128_256: 31,
    aes_ccm_64_128_128: 32,
    aes_ccm_64_128_256: 33,
    aes_128_cbc: -17_760_703,
    aes_128_ctr: -17_760_704,
    aes_256_cbc: -17_760_705,
    aes_256_ctr: -17_760_706
  ]

  @primary_key false
  typed_schema "to2_sessions" do
    field :session_key, :binary, primary_key: true
    field :device_id, Astarte.DataAccess.UUID
    field :sig_type, Ecto.Enum, values: [es256: -7, es384: -35, eipd10: 90, eipd11: 91]
    field :epid_group, :binary
    field :device_public_key, :binary
    field :prove_dv_nonce, :binary
    field :kex_suite_name, :string
    field :cipher_suite_name, Ecto.Enum, values: @ciphers
    field :owner_random, :binary
    field :secret, :binary
    field :sevk, :binary
    field :svk, :binary
    field :sek, :binary
    field :max_service_info, :integer 
  end
end
