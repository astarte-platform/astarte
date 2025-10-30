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

defmodule Astarte.PairingWeb.OwnershipVoucherController do
  use Astarte.PairingWeb, :controller

  alias Astarte.Pairing.FDO.OwnershipVoucher

  action_fallback Astarte.PairingWeb.FallbackController

  def create(conn, %{
        "ownership_voucher" => voucher,
        "private_key" => key,
        "realm_name" => realm_name
      }) do
    with :ok <- OwnershipVoucher.save_voucher(realm_name, voucher, key) do
      send_resp(conn, 200, "")
    end
  end
end
