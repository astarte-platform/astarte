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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo do
  @type t :: :es256 | :es384 | :rs256 | :rs384 | {:eipd10, binary()} | {:eipd11, binary()}
  @es256 -7
  @es384 -35
  @eipd10 90
  @eipd11 91

  def decode(sig_info) do
    case sig_info do
      [@es256, <<>>] -> {:ok, :es256}
      [@es384, <<>>] -> {:ok, :es384}
      [@eipd10, gid] -> {:ok, {:eipd10, gid}}
      [@eipd11, gid] -> {:ok, {:eipd11, gid}}
      _ -> :error
    end
  end
end
