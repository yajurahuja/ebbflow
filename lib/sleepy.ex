defmodule DABlock do
  defstruct(
    parent: nil,
    payload: nil
  )

  def new(parent, payload) do
    %DABlock{
      parent: parent,
      payload: payload
    }
  end

  def genesis() do
    new(nil, "da-genesis")
  end
end

defmodule DAClient do
  defstruct(
    id: nil,
    leafs: MapSet.new([DABlock.genesis()]),
    rng_mining: nil
  )

  def new(id) do
    %DAClient{
      id: id,
      rng_mining: MersenneTwister.init(2342 + id)
    }
  end

  def tip(client) do
    leafs = Enum.sort_by(MapSet.to_list(client.leafs),
    &{Utilities.depth(&1), String.starts_with?(&1.payload, "adversarial")}, :desc)
    hd(leafs)
  end

  defp confirmedtip_helper(block, k) do
    cond do
      k == 0 or block == DABlock.genesis() ->
        block
      true ->
        block = block.parent
        confirmedtip_helper(block, k-1)
    end
  end

  def confirmedtip(client, k) do
    b = tip(client)
    confirmedtip_helper(b, k)
  end

  def ledger(client, k) do
    Utilities.confirmedtip(client, k)
  end

  # TODO: allblocks, DAMsgNewBlock and slot! pending to be implemented
end
