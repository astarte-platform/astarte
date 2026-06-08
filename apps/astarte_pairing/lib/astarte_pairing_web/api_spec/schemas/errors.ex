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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.Errors do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule MissingTokenResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MissingTokenResponse",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      example: %{
        errors: %{
          detail: "Missing authorization token"
        }
      }
    })
  end

  defmodule InvalidTokenResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InvalidTokenResponse",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      example: %{
        errors: %{
          detail: "Invalid JWT token"
        }
      }
    })
  end

  defmodule InvalidAuthPathResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InvalidAuthPathResponse",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      example: %{
        errors: %{
          detail: "Authorization failed due to an invalid path"
        }
      }
    })
  end

  defmodule AuthorizationPathNotMatchedResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthorizationPathNotMatchedResponse",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      example: %{
        errors: %{
          detail: "Unauthorized access to GET /api/v1/some_path. Please verify your permissions"
        }
      }
    })
  end

  defmodule ForbiddenResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ForbiddenResponse",
      description: "Forbidden response",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      required: [:errors],
      example: %{
        errors: %{
          detail: "Forbidden"
        }
      }
    })
  end

  defmodule GenericErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GenericErrorResponse",
      type: :object,
      properties: %{
        errors: %Schema{type: :object}
      }
    })
  end

  defmodule UnauthorizedResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UnauthorizedResponse",
      description: "Unauthorized response",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string}
          }
        }
      },
      example: %{
        errors: %{
          detail: "Unauthorized"
        }
      }
    })
  end
end
