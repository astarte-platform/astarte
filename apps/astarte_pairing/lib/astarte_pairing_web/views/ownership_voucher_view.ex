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

defmodule Astarte.PairingWeb.OwnershipVoucherView do
  use Astarte.PairingWeb, :view

  alias Astarte.PairingWeb.OwnershipVoucherView
  alias Astarte.DataAccess.FDO.OwnershipVoucher

  def render("list_vouchers.json", %{ownership_vouchers: vouchers}) do
    %{
      data: render_many(vouchers, OwnershipVoucherView, "ownership_voucher.json")
    }
  end

  def render("ownership_voucher.json", %{ownership_voucher: voucher}) do
    %OwnershipVoucher{
      guid: guid,
      replacement_guid: output_guid,
      voucher_data: input_voucher,
      output_voucher: output_voucher,
      status: status
    } = voucher

    guid = render_one(guid, OwnershipVoucherView, "guid.json", as: :guid)
    output_guid = render_one(output_guid, OwnershipVoucherView, "guid.json", as: :guid)
    input_voucher = render_one(input_voucher, OwnershipVoucherView, "binary_voucher.json")
    output_voucher = render_one(output_voucher, OwnershipVoucherView, "binary_voucher.json")

    %{
      guid: guid,
      status: status,
      output_guid: output_guid,
      input_voucher: input_voucher,
      output_voucher: output_voucher
    }
  end

  def render("guid.json", %{guid: guid}) do
    UUID.binary_to_string!(guid)
  end

  def render("binary_voucher.json", %{ownership_voucher: binary_voucher}) do
    # PEMs have 64-character long lines
    encoded =
      Base.encode64(binary_voucher)
      |> String.to_charlist()
      |> Enum.chunk_every(64)
      |> Enum.intersperse("\n")
      |> List.flatten()

    """
    -----BEGIN OWNERSHIP VOUCHER-----
    #{encoded}
    -----END OWNERSHIP VOUCHER-----
    """
  end
end
