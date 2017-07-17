defmodule InterfaceNotFoundError do

  defexception plug_status: 404,
    message: "Interface Not Found"

    def exception(opts) do
      %InterfaceNotFoundError{
      }
    end
end

