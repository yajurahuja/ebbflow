defmodule SleepyTest do
  use ExUnit.Case
  doctest DABlock
  doctest DAClient
  doctest DAMsgNewBlock

  test "DABlock genesis" do
    assert DABlock.genesis().payload == "da-genesis"
  end

  test "new DAClient" do
    genesisDA = DABlock.genesis()
    client = DAClient.new(2, genesisDA)
    assert client.id == 2
    assert MersenneTwister.nextUniform(client.rng_mining)|> elem(0) == 0.5847323557827622
  end

  defp dummy_client() do
    genesisDA = DABlock.genesis()
    client = DAClient.new(2, genesisDA)

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

  test "allblocks" do
    allblocks = DAClient.allblocks(dummy_client())
    assert length(MapSet.to_list(allblocks)) == 6
  end

  test "slot! - genesis client" do
    genesisDA = DABlock.genesis()
    client = DAClient.new(2, genesisDA)
    {_, slot} = DAMsgNewBlock.slot!(client, 2, [], [], :honest, 0.7)
    assert length(slot) == 1
    assert hd(slot).id == 2
    assert hd(slot).t == 2
    assert hd(slot).block.payload == "t=2,id=2"

  end

  test "slot! - dummy client" do
    client = dummy_client()
    {_, slot} = DAMsgNewBlock.slot!(client, 2, [], [], :honest, 0.7)
    assert length(slot) == 1
    assert hd(slot).id == 2
    assert hd(slot).t == 2
    assert hd(slot).block.payload == "t=2,id=2"

  end
end
