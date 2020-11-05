defmodule A2Test do
  use ExUnit.Case
  doctest A2

  test "greets the world" do
    assert A2.hello() == :world
  end
end
