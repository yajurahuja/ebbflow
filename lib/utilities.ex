defmodule Utilities do

  #the following function returns the depth of the block in the block chain
  @spec depth(%PBlock{} | %DABlock{}) :: non_neg_integer()
  def depth(block) do
    if block.parent == nil do
      0
    else
      1 + depth(block.parent)
    end
  end

  #the following function returns the chain ending at the block input
  #chain is a sequence of blocks starting with the genesis block chain[0] with strictly increasing epoch numbers.
  @spec chain(%PBlock{} | %DABlock{}) :: list(%PBlock{})|list(%DABlock{})
  def chain(block) do
    if block.parent == nil do
      [block]
    else
      chain(block.parent) ++ [block]
    end
  end

  #the following function returns the ledger from the block list
  @spec ledger(%PBlock{} | %DABlock{}) :: list(string())
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
