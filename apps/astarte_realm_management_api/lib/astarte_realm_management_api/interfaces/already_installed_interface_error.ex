defmodule AlreadyInstalledInterfaceError do

  defexception plug_status: 409,
    message: "Already Installed Interface"

    def exception(opts) do
      %AlreadyInstalledInterfaceError{
      }
    end
end

