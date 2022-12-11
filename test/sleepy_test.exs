defmodule SleepyTest do
  use ExUnit.Case
  doctest DABlock
  doctest DAClient

  test "DABlock genesis" do
    assert DABlock.genesis().payload == "da-genesis"
  end

  test "new DAClient" do
    client = DAClient.new(2)
    assert client.id == 2
    assert MersenneTwister.nextUniform(client.rng_mining)|> elem(0) == 0.5847323557827622
  end

  defp dummy_client() do
    client = DAClient.new(2)

    # Dummy DABlocks
    block1 = DABlock.new(hd(MapSet.to_list(client.leafs)), "block1")
    block2 = DABlock.new(block1, "block2")
    block3 = DABlock.new(block2, "block3")
    advBlock1 = DABlock.new(block3, "adversarial_block1")
    block4 = DABlock.new(block3, "block4") # same depth as adversarial

    leafs = MapSet.put(client.leafs, block1) |>
    MapSet.put(advBlock1) |>
    MapSet.put(block2) |>
    MapSet.put(block4) |>
    MapSet.put(block3)
    %{client | leafs: leafs}
  end

  # TODO: Verify correct sorting order
  test "tip DAClient" do
    tips = DAClient.tip(dummy_client())
    assert tips.payload == "adversarial_block1"
  end

  test "confirmed tip - k = 1" do
    ctip = DAClient.confirmedtip(dummy_client(), 1)
    assert ctip.payload == "block3"
  end

  test "confirmed tip - k = 2" do
    ctip = DAClient.confirmedtip(dummy_client(), 2)
    assert ctip.payload == "block2"
  end

  test "confirmed tip - k = 3" do
    ctip = DAClient.confirmedtip(dummy_client(), 3)
    assert ctip.payload == "block1"
  end
end
