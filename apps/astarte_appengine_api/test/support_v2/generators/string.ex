defmodule Astarte.Test.Generators.String do
  use ExUnitProperties
  alias StreamData

  def random_string(max) do
    string(:alphanumeric, length: max)
  end

  def endpoint_subpath() do
    string([?a..?z, ?_], min_length: 1, max_length: 5)
  end

  def endpoint_parametric_subpath() do
    gen all subpath <- endpoint_subpath() do
      "%{" <> subpath <> "}"
    end
  end

  def endpoint_prefix() do
    gen all prefix <-
              frequency([
                {1, endpoint_subpath()},
                {1, endpoint_parametric_subpath()}
              ])
              |> list_of(
                min_length: 1,
                max_length: 5
              )
              |> map(&Enum.join(&1, "/")) do
      "/" <> prefix
    end
  end
end
