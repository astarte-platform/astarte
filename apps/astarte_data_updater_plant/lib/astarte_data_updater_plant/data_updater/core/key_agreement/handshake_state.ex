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
  Pure state machine for the Encrypted Endpoints Key Agreement protocol.

  ## States

  * `:uninitialized` — No handshake attempted (initial state or post-reset).
  * `{:handshake_started, data}` — `InitExchange` exchanged; awaiting `ExchangeResp` and derivation.
  * `{:established, data}` — Shared secret derived; ready for encrypted traffic.
  * `{:failed, reason}` — Handshake failed; requires reset or re-initiation.

  ## Valid transitions

  | Current state                                     | Event                             | Next state           |
  |---------------------------------------------------|-----------------------------------|----------------------|
  | any                                               | `:reset`                          | `:uninitialized`     |
  | any                                               | `{:initiate_handshake, msg}`      | `:handshake_started` |
  | `:uninitialized`, `:handshake_started`, `:failed` | `{:receive_init, msg}`            | `:handshake_started` |
  | `:handshake_started`                              | `{:handshake_completed, secret}`  | `:established`       |
  | `:established`                                    | `:secret_reconfirmed`             | `:established`       |
  | any                                               | `{:error, reason}`                | `{:failed, reason}`  |
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange

  require Logger

  @type key_suite :: InitExchange.key_suite()

  @type handshake_data :: %{
          key_type: key_suite(),
          init_exchange: InitExchange.t()
        }

  @type established_data :: %{
          shared_secret: binary(),
          alg: key_suite()
        }

  @type t ::
          :uninitialized
          | {:handshake_started, handshake_data()}
          | {:established, established_data()}
          | {:failed, reason :: term()}

  @doc """
  Pure transition function. Cryptographic derivation must be performed
  externally by the caller.

  Returns `{:ok, new_state}` on a valid transition, or
  `{:error, :invalid_transition}` when the (state, event) pair is not
  permitted by the protocol.
  """
  @spec transition(t(), term()) :: {:ok, t()} | {:error, :invalid_transition}

  # `:reset` is always valid, covers session reconnect and post-failure recovery
  def transition(_current_state, :reset) do
    {:ok, :uninitialized}
  end

  # Either party may trigger a new handshake from any state (e.g. key rotation).
  def transition(_current_state, {:initiate_handshake, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  # Receiving a handshake initiation (Device to Astarte).
  def transition(:uninitialized, {:receive_init, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  def transition({:handshake_started, _}, {:receive_init, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  def transition({:failed, _}, {:receive_init, %InitExchange{} = msg}) do
    {:ok, {:handshake_started, %{key_type: msg.key_type, init_exchange: msg}}}
  end

  # Successful handshake completion (Result of SharedSecret.derive/3)
  def transition(
        {:handshake_started, %{key_type: alg}},
        {:handshake_completed, shared_secret}
      )
      when is_binary(shared_secret) do
    {:ok, {:established, %{shared_secret: shared_secret, alg: alg}}}
  end

  # SecretHash successfully verified while already established
  def transition({:established, data}, :secret_reconfirmed) do
    {:ok, {:established, data}}
  end

  # Error transition
  def transition(_current_state, {:error, reason}) do
    {:ok, {:failed, reason}}
  end

  # Fallback for invalid protocol steps
  def transition(current_state, event) do
    Logger.warning(
      "Handshake: tried to transition with event #{inspect(event)} from state #{inspect(current_state)}"
    )

    {:error, :invalid_transition}
  end
end
