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

defmodule Astarte.FDO.ServiceInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.ServiceInfo

  @service_info %{
    "astarte:active" => true,
    "astarte:baseurl" => "http://api.astarte.localhost:80",
    "astarte:deviceid" => "3p_g1OzCRWetKic8CEvznA",
    "astarte:realm" => "test",
    "astarte:secret" => "4g3F3SrxCdx4yPcpZlUlQdTuBJWnvuzAKRVKeGSfiJI="
  }

  test "to_chunks/2 splits a large ServiceInfo into chunks" do
    chunks = ServiceInfo.to_chunks(@service_info, 100)

    assert length(chunks) > 1
  end

  test "each chunk does not exceed max_chunk_size" do
    max_chunk_size = 100

    chunks = ServiceInfo.to_chunks(@service_info, max_chunk_size)

    Enum.each(chunks, fn chunk ->
      size =
        chunk
        |> CBOR.encode()
        |> byte_size()

      assert size <= max_chunk_size
    end)
  end

  test "does not split when service_info fits in a single chunk" do
    chunks = ServiceInfo.to_chunks(@service_info, 10_000)

    assert length(chunks) == 1
  end

  test "each chunk contains at least one entry" do
    chunks = ServiceInfo.to_chunks(@service_info, 100)

    Enum.each(chunks, fn chunk ->
      assert length(chunk) > 0
    end)
  end

  test "returns empty list for empty service_info" do
    chunks = ServiceInfo.to_chunks(%{}, 100)

    assert chunks == []
  end
end
