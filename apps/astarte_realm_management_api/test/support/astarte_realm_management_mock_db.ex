defmodule Astarte.RealmManagement.Mock.DB do
  alias Astarte.Core.Interface
  alias Astarte.RealmManagement.API.JWTTestHelper

  def start_link do
    Agent.start_link(fn -> %{interfaces: %{}} end, name: __MODULE__)
  end

  def drop_interfaces() do
    Agent.update(__MODULE__, &Map.put(&1, :interfaces, %{}))
  end

  def delete_interface(realm, name, major) do
    if get_interface(realm, name, major) == nil do
      {:error, :interface_not_found}
    else
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.delete(interfaces, {realm, name, major})}
      end)
    end
  end

  def get_interfaces_list(realm) do
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
      keys = Map.keys(interfaces)

      for {^realm, name, _major} <- keys do
        name
      end
      |> Enum.uniq()
    end)
  end

  def get_interface_versions_list(realm, name) do
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
      keys = Map.keys(interfaces)

      majors =
        for {^realm, ^name, major} <- keys do
          major
        end

      versions =
        for major <- majors do
          %Interface{minor_version: minor} = Map.get(interfaces, {realm, name, major})
          [major_version: major, minor_version: minor]
        end
    end)
  end

  def get_interface_source(realm, name, major) do
    if interface = get_interface(realm, name, major) do
      Poison.encode!(interface)
    else
      nil
    end
  end

  def get_interface(realm, name, major) do
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
      Map.get(interfaces, {realm, name, major})
    end)
  end

  def get_jwt_public_key_pem(realm) do
    Agent.get(__MODULE__, &Map.get(&1, "jwt_public_key_pem_#{realm}"))
  end

  def install_interface(realm, %Interface{name: name, major_version: major} = interface) do
    if get_interface(realm, name, major) != nil do
      {:error, :already_installed_interface}
    else
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    end
  end

  def update_interface(realm, %Interface{name: name, major_version: major} = interface) do
    # Some basic error checking simulation
    with {:old_interface, old_interface} when not is_nil(old_interface) <-
           {:old_interface, get_interface(realm, name, major)},
         {:different_minor, true} <-
           {:different_minor, old_interface.minor_version != interface.minor_version},
         {:minor_bumped, true} <-
           {:minor_bumped, old_interface.minor_version < interface.minor_version} do
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    else
      {:old_interface, nil} ->
        {:error, :interface_major_version_does_not_exist}

      {:different_minor, false} ->
        {:error, :minor_version_not_increased}

      {:minor_bumped, false} ->
        {:error, :downgrade_not_allowed}
    end
  end

  def put_jwt_public_key_pem(realm, jwt_public_key_pem) do
    Agent.update(__MODULE__, &Map.put(&1, "jwt_public_key_pem_#{realm}", jwt_public_key_pem))
  end
end
