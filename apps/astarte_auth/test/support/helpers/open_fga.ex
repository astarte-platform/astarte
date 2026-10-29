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

defmodule Astarte.Auth.Helpers.OpenFGA do
  @moduledoc """
  Sets up stores on the OpenFGA server at the configured openfga_url.
  """

  import ExUnit.Assertions

  alias Astarte.Auth.OpenFGA.Client

  @doc """
  A store name no other test uses.
  """
  def unique_store_name do
    "astarte_auth_test_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  @doc """
  Creates a store, deleted when the test (or the module, from `setup_all`)
  exits, and returns its id.
  """
  def create_store!(store_name) do
    %{"id" => store_id} = post!("/stores", %{name: store_name})
    ExUnit.Callbacks.on_exit(fn -> Client.delete!("/stores/#{store_id}") end)
    store_id
  end

  @doc """
  Writes `model`, an authorization model in its JSON shape, to the store.
  """
  def write_model!(store_id, model) do
    post!("/stores/#{store_id}/authorization-models", model)
  end

  @doc """
  Writes `tuples` to the store.
  """
  def write_tuples!(store_id, tuples) do
    # OpenFGA takes at most 100 tuples per write.
    for chunk <- Enum.chunk_every(tuples, 100) do
      post!("/stores/#{store_id}/write", %{writes: %{tuple_keys: chunk}})
    end

    :ok
  end

  defp post!(url, body) do
    %HTTPoison.Response{status_code: status, body: resp_body} =
      Client.post!(url, Jason.encode!(body), [{"Content-Type", "application/json"}])

    assert status in 200..299, "OpenFGA returned #{status}: #{resp_body}"
    Jason.decode!(resp_body)
  end
end
