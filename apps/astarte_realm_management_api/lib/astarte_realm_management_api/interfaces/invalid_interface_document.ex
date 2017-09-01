defmodule InvalidInterfaceDocumentError do

  defexception plug_status: 405,
    message: "Invalid Interface Document"

    def exception(opts) do
      %InvalidInterfaceDocumentError{
      }
    end
end

