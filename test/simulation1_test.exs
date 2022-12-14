defmodule Simulation1Test do
  use ExUnit.Case
  doctest NPSimulation

  test "getpartition t < 600" do
    assert NPSimulation.getpartition(%NPSimulation{}, 500) == {false, -1}
  end

  test "getpartition 600 < t < 1200" do
    assert NPSimulation.getpartition(%NPSimulation{}, 700) == {true, 0}
  end

  test "getpartition 1200 < t < 1800" do
    assert NPSimulation.getpartition(%NPSimulation{}, 1300) == {false, -1}
  end

  test "getpartition 1800 < t < 2700" do
    assert NPSimulation.getpartition(%NPSimulation{}, 1900) == {true, 1}
  end

  test "getpartition 2700 < t" do
    assert NPSimulation.getpartition(%NPSimulation{}, 2800) == {false, -1}
  end

  test "ispartitioned t = 700" do
    assert NPSimulation.ispartitioned(%NPSimulation{}, 700) == true
  end

  test "new NPSimulation" do
    sim = NPSimulation.new(11, 1)
    assert sim.validatorsPart1 == [0, 1, 2, 3, 4, 5]
  end
end
