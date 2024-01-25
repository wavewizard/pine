defmodule PineTest do
  use ExUnit.Case
  doctest Pine

  test "greets the world" do
    assert Pine.hello() == :world
  end
end
