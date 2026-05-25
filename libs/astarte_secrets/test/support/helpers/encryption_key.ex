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

defmodule Astarte.Helpers.EncryptionKey do
  @moduledoc false

  require Logger

  alias Astarte.Secrets.Client

  @doc """
  Creates an AES-256-GCM transit key in OpenBao under the given name and namespace.

  This is a test-only helper, used until a proper public API is available in
  `Astarte.Secrets`.
  """
  def create_encryption_key(key_name, namespace) do
    headers = [{"Content-Type", "application/json"}]

    case Client.post(
           "/transit/keys/#{key_name}",
           Jason.encode!(%{type: "aes256-gcm96"}),
           headers,
           namespace: namespace
         ) do
      {:ok, %{status_code: s}} when s in [200, 204] ->
        :ok

      {:ok, %{status_code: 400, body: body}} when is_binary(body) ->
        if body =~ "already in use", do: :ok, else: :error

      other ->
        Logger.error(
          "Failed to create KEK #{key_name} in namespace #{namespace}: #{inspect(other)}"
        )

        :error
    end
  end
end
