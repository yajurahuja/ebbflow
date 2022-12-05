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
    leafs: nil,
    rng_mining: nil #What is this? Maybe random number generator
  )
end
