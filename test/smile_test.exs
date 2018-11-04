defmodule SmileTest do
  use ExUnit.Case
  doctest Smile

  test "greets the world" do
    assert Smile.hello() == :world
  end
end
