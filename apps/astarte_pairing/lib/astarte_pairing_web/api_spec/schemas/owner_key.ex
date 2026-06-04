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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.OwnerKey do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule CreateOrUploadOwnerKeyRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateOrUploadOwnerKeyRequest",
      type: :object,
      properties: %{
        action: %Schema{
          type: :string,
          enum: ["create", "upload"],
          description: "Whether to create a new key or upload an existing one."
        },
        key_name: %Schema{
          type: :string,
          description: "The name to assign to the key."
        },
        key_algorithm: %Schema{
          type: :string,
          enum: ["ecdsa-p256", "ecdsa-p384", "rsa-2048", "rsa-3072"],
          description:
            "The algorithm to use for key creation. Required when action is \"create\"."
        },
        key_data: %Schema{
          type: :string,
          description:
            "The PEM-encoded private key to upload. Required when action is \"upload\"."
        }
      },
      required: [:action, :key_name]
    })
  end
end
