defmodule Astarte.RealmManagement.API.RealmNotFoundError do

  defexception plug_status: 403,
    message: "Forbidden"

    def exception(_opts) do
      %Astarte.RealmManagement.API.RealmNotFoundError{
      }
    end
end

