defmodule Astarte.RealmManagement.API.AlreadyInstalledInterfaceError do

  defexception plug_status: 409,
    message: "Already Installed Interface"

    def exception(opts) do
      %Astarte.RealmManagement.API.AlreadyInstalledInterfaceError{
      }
    end
end

