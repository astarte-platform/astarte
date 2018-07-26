#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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
