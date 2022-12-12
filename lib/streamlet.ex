defmodule PBlock do

  #import useful things
  #This structure contains all the process state required by PBlock
  defstruct(
   parent: nil,
   epoch: nil,
   payload: nil
  )

  def new(parent, epoch, payload) do
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

  def leader(t, n, bft_delay) do
    e = epoch(t, bft_delay)
    #TODO: fix seeding according to TSE group, check if required
    l = Enum.random(1..n)
  end

end

defmodule PClient do
  #This structure contains all the process state required by the PClient
  defstruct(
    id: nil,
    client_da: nil,
    leafs: nil,
    votes: nil,
    current_epoch_proposal: nil
  )

  def new(id, client_da) do
    %PClient{
      id: id,
      client_da: client_da,
      leafs: MapSet.new([PBlock.genesis()]),
      votes: %{}, #Key => Value:  PBlock => Set{int}
      current_epoch_proposal: nil
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

  def lastnotarized(client, block, n) do
    #while the the block for a client is not notarized, we go up in the blockchain
    lastnotarized_block =
      if not isnotarized(client, block, n) do
        lastnotarized(client, block.parent, n)
      else
        block
      end
    lastnotarized_block
  end

  #this is a helper function for the tip function
  defp tip_helper(client, leafs, best_block, best_depth, n) do
    if length(leafs) == 0 do
      {best_block, best_depth}
    else
      head = hd(leafs)
      l = lastnotarized(client, head, n)
      tail = tl(leafs)
      {best_block, best_depth} =
      if Utilities.depth(l) > best_depth do
        best_block = l
        best_depth = Utilities.depth(best_block)
        {best_block, best_depth}
      else
        {best_block, best_depth}
      end
      tip_helper(client, tail, best_block, best_depth, n)
    end
  end

  #this function returns the tip block in the longest chain of the blockchain
  def tip(client, n) do
    best_block = PBlock.genesis()
    best_depth = Utilities.depth(best_block)
    leafs = MapSet.to_list(client.leafs)
    #travese through all leafs and find the one with the maximum depth
    {best_block, best_depth} = tip_helper(client, leafs, best_block, best_depth, n)
    best_block
  end

  def finalizedtip_helperwhile(client, leaf, best_block, best_depth, n) do
    if Utilities.depth(leaf) <= 3 or Utilities.depth(leaf) <= best_depth do
      {best_block, best_depth}
    else
      b0 = leaf.parent.parent
      b1 = leaf.parent
      b2 = leaf
      {best_block, best_depth} =
        if isnotarized(client, b0, n) and
        isnotarized(client, b1, n) and
        isnotarized(client, b2, n) and (b0.epoch == b2.epoch - 2) and (b1.epoch == b2.epoch - 1) and Utilities.depth(b1) > best_depth do
          best_block = b1
          best_depth = Utilities.depth(best_block)
          {best_block, best_depth}
        else
          finalizedtip_helperwhile(client, leaf.parent, best_block, best_depth, n)
        end
      {best_block, best_depth}
    end
  end
  #this is a helper function to the finalized tip function
  def finalizedtip_helper(client, leafs, best_block, best_depth, n) do
    if length(MapSet.to_list(leafs)) == 0 do
      {best_block, best_depth}
    else
      head = hd(leafs)
      tail = tl(leafs)
      {best_block, best_depth} = finalizedtip_helperwhile(client, head, best_block, best_depth, n)
      finalizedtip_helper(client, tail, best_block, best_depth, n)
    end
  end

 #this function returns the finlized tip block in the longest chain of the blockchain
  def finalizedtip(client, n) do
      best_block = PBlock.genesis()
      best_depth = Utilities.depth(best_block)
      leafs = MapSet.to_list(client.leafs)
      leafs = Enum.sort(leafs, fn x -> Utilities.depth(x) end)
      leafs = Enum.reverse(leafs)
      #travese through all leafs
      {best_block, best_depth} = finalizedtip_helper(client, leafs, best_block, best_depth, n)
      best_block
  end


  #This function returns the ledger
  def ledger(client, n) do
    Utilities.ledger(finalizedtip(client, n))
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


  #slot helper function
  def slot_helper(client, t, msg_in, bft_delay) do
    if length(msg_in) == 0 do
      client
    else
      msg = hd(msg_in)
      client =
      if msg == %PMsgProposal{} do
        #update leafs
        updated_leafs = MapSet.difference(client.leafs, MapSet.new([msg.block.parent]))
        updated_leafs = MapSet.put(updated_leafs, msg.block)
        client = {client | leafs: updated_leafs}
        client.votes[m.block] = MapSet.new()
        #update current_epoch_proposal
        client =
          if msg.block.epoch ==  PBlock.epoch(t, bft_delay) and client.current_proposal == nil do
            client.current_proposal = m.block
            client
          else
            client
          end
        slot_helper(client, t, tl(msgs_in), bft_delay)
      else
        slot_helper(client, t, tl(msgs_in), bft_delay)
      end
    end
  end

  def slot_vote_helper(client, msgs_in) do
    if len(msgs_in) == 0 do
      client
    else
      msg = hd(msgs_in)
      if msg == %PMsgVote{} do
        updated_votes = Map.put(client.votes, msg.block, msg.id)
        client = {client | votes: updated_votes}
        slot_vote_helper(client, tl(msgs_in))
      else
        slot_vote_helper(client, tl(msgs_in))
      end
    end
  end

  def slot(client, t, msgs_out, msgs_in, bft_delay, n) do
    #update proposal
    client = slot_helper(client, t, msgs_in)
    #update votes
    client = slot_vote_helper(client, msgs_in)
    {client, msgs_out} =
    if t % (2 * bft_delay) == 0 do
      client = {client | current_epoch_proposal: nil}
      msgs_out =
      if leader(t, n, bft_delay) == client.id do
        new_pblock = PBlock.new(tip(client), epoch(t), confirmed_tip(client.client_da))
        msgs_out ++ [PMsgProposal.new(t, client.id, new_pblock)]
      else
        msgs_out
      end
      {client, msgs_out}
    else
      msgs_out =
      if  t % (2 * bft_delay) == bft_delay and client.current_epoch_proposal != 0 do
        msgs_out ++ [PMsgVote.new(t, client.id, client.current_epoch_proposal)]
      else
        msgs_out
      end
      {client, msgs_out}
    end
    {client, msgs_out}
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
