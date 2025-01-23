# Copyright 2018-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.Pairing.CredentialsSecret do
  @moduledoc """
  This module is responsible for generating and verifying the credential secrets
  """

  alias Astarte.Pairing.CredentialsSecret.Cache

  @secret_bytes_length 32

  @doc """
  Generates a random credential secret
  """
  def generate do
    :crypto.strong_rand_bytes(@secret_bytes_length)
    |> Base.encode64()
  end

  @doc """
  Generates the Bcrypt hash from a secret
  """
  def hash(secret) do
    sha_hash = :crypto.hash(:sha256, secret)
    bcrypt_hash = Bcrypt.hash_pwd_salt(secret)
    Cache.put(sha_hash, bcrypt_hash)

    bcrypt_hash
  end

  @doc """
  Verifies the credential secret against the DB hash.

  Returns true if they match, false if they don't.

  If the secret or the stored hash are nil, it performs a dummy check to avoid timing attacks.
  """
  def verify(nil, _stored_hash) do
    false
  end

  def verify(_provided_secret, nil) do
    false
  end

  def verify(provided_secret, stored_hash) do
    sha_hash = :crypto.hash(:sha256, provided_secret)

    with {:ok, bcrypt_hash} <- Cache.fetch(sha_hash) do
      bcrypt_hash == stored_hash
    else
      :error ->
        if Bcrypt.verify_pass(provided_secret, stored_hash) do
          Cache.put(sha_hash, stored_hash)
          true
        else
          false
        end
    end
  end
end
