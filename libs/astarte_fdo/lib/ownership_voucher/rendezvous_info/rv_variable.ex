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

defmodule Astarte.FDO.OwnershipVoucher.RendezvousInfo.RVVariable do
  @moduledoc """
  RVVariable conversion module.
  """
  @rv_map %{
    0 => :dev_only,
    1 => :owner_only,
    2 => :ip_address,
    3 => :dev_port,
    4 => :owner_port,
    5 => :dns,
    6 => :sv_cert_hash,
    7 => :cl_cert_hash,
    8 => :user_input,
    9 => :wifi_ssid,
    10 => :wifi_pw,
    11 => :medium,
    12 => :protocol,
    13 => :delaysec,
    14 => :bypass,
    15 => :ext_rv
  }

  @type t ::
          :dev_only
          | :owner_only
          | :ip_address
          | :dev_port
          | :owner_port
          | :dns
          | :sv_cert_hash
          | :cl_cert_hash
          | :user_input
          | :wifi_ssid
          | :wifi_pw
          | :medium
          | :protocol
          | :delaysec
          | :bypass
          | :ext_rv

  @rv_reverse Map.new(@rv_map, fn {k, v} -> {v, k} end)

  def decode(u8), do: Map.fetch(@rv_map, u8)
  def encode(atom), do: Map.fetch!(@rv_reverse, atom)
end
