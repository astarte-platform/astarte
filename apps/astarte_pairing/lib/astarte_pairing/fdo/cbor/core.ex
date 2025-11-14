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

defmodule Astarte.Pairing.FDO.Cbor.Core do
  @sha256 47
  def empty_payload() do
    CBOR.encode([])
  end

  def build_rv_to2_addr_entry(ip, dns, port, protocol) do
    rv_entry = [ip, dns, port, protocol]
    CBOR.encode([rv_entry])
  end

  def build_to1d_rv(entries) do
    CBOR.encode([entries])
  end

  def build_to0d(ov, wait_seconds, nonce) do
    CBOR.encode([ov, wait_seconds, add_cbor_tag(nonce)])
  end

  def add_cbor_tag(payload) do
    %CBOR.Tag{tag: :bytes, value: payload}
  end

  def build_to1d_to0d_hash(to0d) do
    to1d_to0d_hash_value = :crypto.hash(:sha256, to0d)

    CBOR.encode([@sha256, to1d_to0d_hash_value])
  end

  def build_to1d_blob_payload(to1d_rv, to1d_to0d_hash) do
    CBOR.encode([to1d_rv, to1d_to0d_hash])
  end
end
