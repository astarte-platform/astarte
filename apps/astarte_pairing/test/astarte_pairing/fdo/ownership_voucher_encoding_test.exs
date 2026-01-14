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

defmodule Astarte.Pairing.FDO.OwnershipVoucherEncodingTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Helpers.FDO

  test "encode_voucher_to_cbor/1 dynamically reconstructs valid CBOR from static sample" do
    original_cbor = FDO.sample_cbor_voucher()

    {:ok, voucher_struct} = OwnershipVoucher.decode_cbor(original_cbor)

    re_encoded_cbor = OwnershipVoucher.cbor_encode(voucher_struct)

    assert original_cbor == re_encoded_cbor
  end
end
