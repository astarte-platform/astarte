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

defmodule Astarte.AppEngine.APIWeb.ApiSpec.Schemas.Errors do
  @moduledoc false

  defmodule NotFoundError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "NotFoundError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Short error description"}
          }
        }
      },
      example: %{
        errors: %{detail: "Device not found"}
      }
    })
  end

  defmodule UnauthorizedError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "UnauthorizedError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Short error description"}
          }
        }
      },
      example: %{
        errors: %{detail: "Unauthorized"}
      }
    })
  end

  defmodule MissingTokenError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "MissingTokenError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Short error description"}
          }
        }
      },
      example: %{
        errors: %{detail: "Missing authorization token"}
      }
    })
  end

  defmodule InvalidTokenError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "InvalidTokenError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Short error description"}
          }
        }
      },
      example: %{
        errors: %{detail: "Invalid JWT token"}
      }
    })
  end

  defmodule InvalidAuthPathError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "InvalidAuthPathError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Short error description"}
          }
        }
      },
      example: %{
        errors: %{detail: "Authorization failed due to an invalid path"}
      }
    })
  end

  defmodule AuthorizationPathNotMatchedError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "AuthorizationPathNotMatchedError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{
              type: :string,
              description: "Detailed error message including the method and path"
            }
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

  defmodule GroupNotFoundError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "GroupNotFoundError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{
              type: :string,
              description: "Short error description",
              example: "Group not found"
            }
          }
        }
      },
      example: %{
        errors: %{detail: "Group not found"}
      }
    })
  end

  defmodule GroupOrDeviceNotFoundError do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "GroupOrDeviceNotFoundError",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{
              type: :string,
              description: "Short error description",
              example: "Device not found"
            }
          }
        }
      },
      example: %{
        errors: %{detail: "Device not found"}
      }
    })
  end
end
