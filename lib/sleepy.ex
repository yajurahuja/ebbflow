defmodule DABlock do
  defstruct(
    parent: nil,
    payload: nil
  )

  def new_DABlock(parent, payload) do
    %DABlock{
      parent: parent,
      payload: payload
    }
  end

  def genesis() do
    new_DABlock(nil, "da-genesis")
  end
end

defmodule DAClient do
  defstruct(
    id: nil,
    leafs: MapSet.new([DABlock.genesis()]),
    rng_mining: nil #What is this? Maybe random number generator
  )

  def tip(client) do
    #leafs = Enum.sort(, fn x -> )
    leafs[0]
  end

  defp confirmedtip_helper(block, k) do
    cond do
      k == 0 ->
        block
      block == block == DABlock.genesis() ->
        block
      true ->
        block.parent
    end
  end
  def confirmedtip(client, k) do
    b = tip(client)


  end

end
