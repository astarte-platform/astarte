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

defmodule Astarte.Pairing.FDO.OpenBao.Key do
  @moduledoc """
  `COSE.Keys.Key` implementation for OpenBao keys.
  """

  use TypedStruct

  alias Astarte.Pairing.FDO.OpenBao.Core

  typedstruct do
    field :name, String.t()
    field :namespace, String.t()
    field :alg, Core.key_algorithm()
  end
end

defimpl COSE.Keys.Key, for: Astarte.Pairing.FDO.OpenBao.Key do
  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Key

  def sign(key, digest_type, to_be_signed) do
    %Key{name: name, namespace: namespace, alg: algorithm} = key
    opts = [namespace: namespace]

    with :error <- OpenBao.sign(name, to_be_signed, algorithm, digest_type, opts) do
      {:error, :signature_error}
    end
  end

  def verify(_key, _digest_type, _to_be_verified, _signature) do
    raise "`Astarte.Pairing.FDO.OpenBao.Key.verify/4`: Not yet implemented"
  end
end
