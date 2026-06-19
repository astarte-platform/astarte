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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState do
  @moduledoc """
  Pure state machine for Encrypted Endpoints Key Agreement protocol.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange

  @type key_suite :: InitExchange.key_suite()

  @type t ::
          :uninitialized
          | {:handshake_started, %{key_type: key_suite(), init_exchange: InitExchange.t()}}
          | {:established, %{shared_secret: binary(), alg: key_suite()}}
          | {:failed, reason :: term()}

  @doc """
  Pure transition function. Cryptographic derivation must be performed
  externally by the caller.
  """
  @spec transition(t(), term()) :: {:ok, t()} | {:error, term()}

  # Initiating a handshake (Astarte to Device)
  def transition(:uninitialized, {:initiate_handshake, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  # Receiving a handshake initiation (Device to Astarte)
  def transition(:uninitialized, {:receive_init, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  # Successful handshake completion (Result of SharedSecret.derive/3)
  def transition({:handshake_started, %{key_type: alg}}, {:handshake_completed, shared_secret}) do
    {:ok, {:established, %{shared_secret: shared_secret, alg: alg}}}
  end

  # Error transition
  def transition(_current_state, {:error, reason}) do
    {:ok, {:failed, reason}}
  end

  # Fallback for invalid protocol steps
  def transition(_current_state, _event), do: {:error, :invalid_transition}
end
