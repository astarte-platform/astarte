defmodule Astarte.RealmManagement.API.InvalidInterfaceDocumentError do

  defexception plug_status: 405,
    message: "Invalid Interface Document"

    def exception(opts) do
      %Astarte.RealmManagement.API.InvalidInterfaceDocumentError{
      }
    end
end

