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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.AuthConfig do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      jwt_public_key_pem: %Schema{
        type: :string,
        example: """
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsj7/Ci5Nx+ApLNW7+DyE
        eTzQ68KEJT/gPW73Kpa2uyvxDwY669z/rP4hMj16wv4Ku3bI6C1ZIqT5SVuF8pDo
        1Y1SF0GRIeslupm9KV1aFqIu1/srLz18LQHucQYUSa99PStFUJY2V83wneaeAArY
        4VKDuQYtRZOd2VeD5Cbn602ksLLWCQc9HfL3VUHXTw6DuthnMMJARcVem8RAMScm
        htGi6YRPFzvHtkb1WQCNGjw5gAmHX5/37ouwbBdnXOa9deiFv+1UIdcCVwMTyP/4
        f9jgaxW4oQV85enS/OJrrC9jU11agRc4bDv1h4s2t+ETWb4llTVk3HMIHbC3EvKJ
        VwIDAQAB
        -----END PUBLIC KEY-----
        """
      }
    }
  })
end
