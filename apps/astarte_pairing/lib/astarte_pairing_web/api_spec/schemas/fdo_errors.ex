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
defmodule Astarte.PairingWeb.ApiSpec.Schemas.FDOErrors do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule InvalidJWTTokenResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOInvalidJWTTokenResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 1,
          description: "FDO error code: 1 (invalid_jwt_token)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 1, correlation_id: 123_456_789}
    })
  end

  defmodule ResourceNotFoundResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOResourceNotFoundResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 6,
          description: "FDO error code: 6 (resource_not_found)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 6, correlation_id: 123_456_789}
    })
  end

  defmodule MessageBodyErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOMessageBodyErrorResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 100,
          description: "FDO error code: 100 (message_body_error)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 100, correlation_id: 123_456_789}
    })
  end

  defmodule InvalidMessageErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOInvalidMessageErrorResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 101,
          description: "FDO error code: 101 (invalid_message_error)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 101, correlation_id: 123_456_789}
    })
  end

  defmodule CredReuseErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOCredReuseErrorResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 102,
          description: "FDO error code: 102 (cred_reuse_error)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 102, correlation_id: 123_456_789}
    })
  end

  defmodule InternalServerErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "FDOInternalServerErrorResponse",
      type: :object,
      properties: %{
        error_code: %Schema{
          type: :integer,
          example: 500,
          description: "FDO error code: 500 (internal_server_error)"
        },
        correlation_id: %Schema{
          type: :integer,
          description: "Correlation ID for tracing the request."
        }
      },
      required: [:error_code],
      example: %{error_code: 500, correlation_id: 123_456_789}
    })
  end
end
