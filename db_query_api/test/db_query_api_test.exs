defmodule DbQueryAPITest do
  use ExUnit.Case
  doctest DbQueryAPI

  test "greets the world" do
    assert DbQueryAPI.hello() == :world
  end
end
