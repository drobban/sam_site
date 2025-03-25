defmodule SamSiteTest do
  use ExUnit.Case
  doctest SamSite

  test "greets the world" do
    assert SamSite.hello() == :world
  end
end
