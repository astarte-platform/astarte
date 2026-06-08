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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.KeyExchangeStrategy do
  @moduledoc """
  Implements the validation logic for FDO Key Exchange suites.
  It verifies that the Key Exchange suite selected by the Device (kexSuiteName)
  is compatible with the Owner's Private Key curve.
  """

  alias COSE.Keys.{ECC, RSA}

  @ecdh256 "ECDH256"
  @ecdh384 "ECDH384"
  @dhkex14 "DHKEXid14"
  @dhkex15 "DHKEXid15"
  @asymkex2048 "ASYMKEX2048"
  @asymkex3072 "ASYMKEX3072"

  @doc """
  Validates the Device's Key Exchange choice against the Owner's Key.

  ## Parameters
  - `device_kex_name`: The string identifying the suite chosen by the device (e.g., "ECDH256").
  - `owner_key`: The COSE Key struct representing the Owner's private key.
  """
  @spec validate(String.t(), struct()) :: :ok | {:error, :invalid_message}
  def validate(device_kex_name, owner_key) do
    case {device_kex_name, owner_key} do
      {dkn, %RSA{alg: :rs256}} when dkn in [@dhkex14, @asymkex2048] ->
        :ok

      {dkn, %RSA{alg: :rs384}} when dkn in [@dhkex15, @asymkex3072] ->
        :ok

      {@ecdh256, %ECC{crv: :p256}} ->
        :ok

      {@ecdh384, %ECC{crv: :p384}} ->
        :ok

      _ ->
        {:error, :invalid_message}
    end
  end
end
