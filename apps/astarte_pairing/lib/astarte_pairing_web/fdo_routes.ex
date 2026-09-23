defmodule Astarte.PairingWeb.FDORoutes do
  @moduledoc """
  defines a macro for reusing fdo routes
  """
  defmacro fdo_routes do
    quote do
      pipe_through :fdo

      post "/msg/60", FDOOnboardingController, :hello_device

      pipe_through :fdo_session

      post "/msg/62", FDOOnboardingController, :ov_next_entry

      post "/msg/64", FDOOnboardingController, :prove_device

      pipe_through :fdo_tunnel

      post "/msg/66", FDOOnboardingController, :service_info_start
      post "/msg/68", FDOOnboardingController, :service_info_end
      post "/msg/70", FDOOnboardingController, :done
    end
  end
end
