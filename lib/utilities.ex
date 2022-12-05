defmodule Utilities do

  #the following function returns the depth of the block in the block chain
  def depth(block) do
    if block.parent == nil do
      0
    else
      1 + depth(block)
    end
  end

  #the following function returns the chain ending at the block input
  #chain is a sequence of blocks starting with the genesis block chain[0] with strictly increasing epoch numbers.
  def chain(block) do
    if block.parent == nil do
      [block]
    else
      chain(block.parent) ++ [block]
    end
  end

 #the following function returns the ledger from the block list
  def ledger(block) do
    if block.parent == nil do
      [block.payload]
    else
      ledger(block.parent) ++ [block.payload]
    end
  end

end
