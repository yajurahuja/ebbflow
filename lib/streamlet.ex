defmodule PBlock do

  #import useful things
  #This structure contains all the process state required by PBlock
  defstruct(
   parent: nil,
   epoch: nil,
   payload: nil
  )

  def new_PBlock(parent, epoch, payload) do
    %PBlock{
      parent: parent,
      epoch: epoch,
      payload: payload
    }
  end

  def genesis() do
    new_PBlock(nil, -1, DABlock.genesis()) #TODO: Fix to return th global genesis block
  end

  def epoch(t, bft_delay) do
    t / (2 * bft_delay)
  end

  def leader(t, n) do
    e = epoch(t, bft_delay)
    #TODO: fix seeding according to TSE group, check if required
    l = Enum.random(1..n)
  end

end

defmodule PClient do
  #This structure contains all the process state required by the PClient
  defstruct(
    id: nil
    client_da: nil
    leafs: nil
    votes: nil
    current_epoch_proposal: nil
  )

  def new_PClient(id, client_da) do
    %PClient{
      id: id,
      client_da: client_da,
      leafs: MapSet.new([PBlock.genesis()]),
      votes: %{}, #Key => Value:  PBlock => Set{int}
      current_epochs_proposal: nil
    }
  end

  def isnotarized(client, block, n) do
    #if the current block is the genesis block: return true
    notarized =
      if block == PBlock.genesis() do #TODO: fix genesis block
        true
      else
        false
      end
    #if length of the votes for of the client for block c are atleast n * 2/3: return true
    notarized =
      if MapSet.size(client.votes) >= (2/3 * n) do #TODO: figure out how to pass n
        true
      else
        false
      end
    notarized
  end

  def lastnotarized(client, block) do
    #while the the block for a client is not notarized, we go up in the blockchain
    lastnotarized_block =
      if not isnotarized(client, block) do
        lastnotarized(client, block.parent)
      else
        block
      end
    lastnotarized_block
  end

  #this is a helper function for the tip function
  defp tip_helper(client, leafs, best_block, best_depth) do
    if length(leafs) == 0 do
      {best_block, best_depth}
    else
      head = hd(leafs)
      l = lastnotarized(client, head)
      tail = tl(leafs)
      {best_block, best_depth} =
      if Utilities.depth(l) > best_depth do
        best_block = l
        best_depth = Utilities.depth(best_block)
        {best_block, best_depth}
      else
        {best_block, best_depth}
      end
      tip_helper(client, tail, best_block, best_depth)
    end
  end

  #this function returns the tip block in the longest chain of the blockchain
  def tip(client) do
    best_block = PBlock.genesis()
    best_depth = Utilities.depth(best_block)
    leafs = MapSet.to_list(client.leafs)
    #travese through all leafs and find the one with the maximum depth
    {best_block, best_depth} = tip_helper(client, leafs, best_block, best_depth)
    best_block
  end

  def finalizedtip_helperwhile(client, leaf, best_block, best_depth) do
    if Utilities.depth(leaf) <= 3 or Utilities.depth(leaf) <= best_depth do
      {best_block, best_depth}
    else
      b0 = leaf.parent.parent
      b1 = leaf.parent
      b2 = leaf
      {best_block, best_depth} =
        if isnotarized(client, b0) and isnotarized(client, b1) and isnotarized(client, b2) and (b0.epoch == b2.epoch - 2) and (b1.epoch == b2.epoch - 1) and Utilities.depth(b1) > best_depth do
          best_block = b1
          best_depth = Utilities.depth(best_block)
          {best_block, best_depth}
        else
          finalizedtip_helperwhile(client, leaf.parent, best_block, best_depth)
        end
      {best_block, best_depth}
    end
  end
  #this is a helper function to the finalized tip function
  def finalizedtip_helper(client, leafs, best_block, best_depth) do
    if len(leafs) == 0 do
      {best_block, best_depth}
    else
      head = hd(leafs)
      tail = tl(leafs)
      {best_block, best_depth} = finalizedtip_helperwhile(client, head, best_block, best_depth)
      finalizedtip_helper(client, tail, best_block, best_depth)
    end
  end

 #this function returns the finlized tip block in the longest chain of the blockchain
  def finalizedtip(client) do
      best_block = PBlock.genesis()
      best_depth = Utilities.depth(best_block)
      leafs = MapSet.to_list(client.leafs)
      leafs = Enum.sort(leafs, fn x -> Utilities.depth(x))
      leafs = Enum.reverse(leafs)
      #travese through all leafs
      {best_block, best_depth} = finalizedtip_helper(client, leafs, best_block, best_depth)
      best_block
  end


  #This function returns the ledger
  def ledger(client) do
    Utilities.ledger(finalizedtip(client))
  end

  #this function is a helper function for the allblocks function
  defp allblocks_helper(leafs) do
    if length(leafs) == 0 do
      MapSet.new()
    else
      head = hd(leafs)
      tail = tl(leafs)
      Mapset.union(MapSet.new(Utilities.chain(head)), allblocks_helper(tail))
    end
  end

  #this funciton returns all blocks
  def allblocks(client) do
    blocks = MapSet.new()
    leafs = MapSet.to_list(client.leafs)
    allblocks_helper(leafs)
  end
end

#TODO: interface for message passing
defmodule PMsgProposal do
  defstruct(
    t: nil,
    id: nil,
    block: nil
  )

  def new(t, id, block) do
    %{
      t: t,
      id: id,
      block: block
    }
  end
end

defmodule PMsgVote do
  defstruct(
    t: nil,
    id: nil,
    block: nil
  )

  def new(t, id, block) do
    %{
      t: t,
      id: id,
      block: block
    }
  end
end
