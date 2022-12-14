defmodule Utilities do

  defp depth_helper(block, depth) do
    if block.parent == nil do
      depth
    else
      depth_helper(block.parent, depth+1)
    end
  end

  #the following function returns the depth of the block in the block chain
  @spec depth(%PBlock{} | %DABlock{}) :: non_neg_integer()
  def depth(block) do
    depth_helper(block, 0)
    # if block.parent == nil do
    #   0
    # else
    #   1 + depth(block.parent)
    # end
  end

  defp chain_helper(block, chain) do
    if block.parent == nil do
      chain ++ [block]
    else
      chain_helper(block.parent, chain ++ [block])
    end
  end

  #the following function returns the chain ending at the block input
  #chain is a sequence of blocks starting with the genesis block chain[0] with strictly increasing epoch numbers.
  @spec chain(%PBlock{} | %DABlock{}) :: list(%PBlock{})|list(%DABlock{})
  def chain(block) do
    chain_helper(block, [])
    # if block.parent == nil do
    #   [block]
    # else
    #   chain(block.parent) ++ [block]
    # end
  end

  #the following function returns the ledger from the block list
  @spec ledger(%PBlock{} | %DABlock{}) :: list(String.t())
  def ledger(block) do
    if block.parent == nil do
      [block.payload]
    else
      ledger(block.parent) ++ [block.payload]
    end
  end

  # Returns true if val is in list
  @spec checkMembership(any(), list(any())) :: boolean()
  def checkMembership(val, list) do
    case list do
      [] -> false
      [head | tail] ->
        if val == head do
          true
        else
          checkMembership(val, tail)
        end
    end
  end

end
