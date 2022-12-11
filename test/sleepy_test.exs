defmodule SleepyTest do
  use ExUnit.Case
  doctest DABlock
  doctest DAClient

  test "DABlock genesis" do
    assert DABlock.genesis().payload == "da-genesis"
  end
end
