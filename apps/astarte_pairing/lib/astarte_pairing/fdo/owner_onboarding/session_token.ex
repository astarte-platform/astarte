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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SessionToken do
  @moduledoc """
  Handles session tokens for FDO.TO2.

  Uses Phoenix.Token to create and verify signed tokens containing:
  - guid: The unique device identifier
  - nonce: A random nonce for replay attack prevention
  """

  alias Phoenix.Token

  @token_salt "fdo_session_token"
  # Token valid for 24 hours
  @max_age 86400

  @doc """
  Generates a signed token containing guid and nonce.

  """
  def generate(guid, nonce) do
    claims = %{guid: guid, nonce: nonce}
    Token.sign(Astarte.PairingWeb.Endpoint, @token_salt, claims)
  end

  @doc """
  Verifies and decodes a token, returning guid and nonce.

  """
  def verify(token) do
    case Token.verify(Astarte.PairingWeb.Endpoint, @token_salt, token, max_age: @max_age) do
      {:ok, %{guid: guid, nonce: nonce}} ->
        {:ok, guid, nonce}

      {:error, reason} ->
        # reason can be :invalid, :missing or :expired
        {:error, reason}
    end
  end
end
