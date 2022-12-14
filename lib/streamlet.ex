defmodule PBlock do

  #import useful things
  #This structure contains all the process state required by PBlock
  defstruct(
   parent: nil,
   epoch: nil,
   payload: nil
  )

  @spec new(%PBlock{} | nil, non_neg_integer(), %DABlock{}) :: %PBlock{}
  def new(parent, epoch, payload) do
    %PBlock{
      parent: parent,
      epoch: epoch,
      payload: payload
    }
  end

  @spec genesis(%DABlock{}) :: %PBlock{}
  def genesis(genesisDA) do
    new(nil, -1, genesisDA) #TODO: Fix to return th global genesis block
  end

  @spec epoch(non_neg_integer(), non_neg_integer()) :: number()
  def epoch(t, bft_delay) do
    t / (2 * bft_delay)
  end

  @spec leader(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def leader(t, n, bft_delay) do
    e = epoch(t, bft_delay)
    
    rng = MersenneTwister.init(4242 + e)

    trunc(elem(MersenneTwister.nextUniform(rng), 0)*n)
  end

end

#TODO: interface for message passing
defmodule PMsgProposal do
  defstruct(
    t: nil,
    id: nil,
    block: nil
  )

  @spec new(non_neg_integer(), non_neg_integer(), %PBlock{}) :: %PMsgProposal{}
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
  @spec new(non_neg_integer(), non_neg_integer(), %PBlock{}) :: %PMsgVote{}
  def new(t, id, block) do
    %{
      t: t,
      id: id,
      block: block
    }
  end
end

defmodule PClient do
  #This structure contains all the process state required by the PClient
  defstruct(
    id: nil,
    client_da: nil,
    leafs: nil,
    votes: nil,
    current_epoch_proposal: nil,
    global_genesis_block: nil
  )

  @spec new(non_neg_integer(), %DAClient{}, %PBlock{}) :: %PClient{}
  def new(id, client_da, global_genesis_block) do
    %PClient{
      id: id,
      client_da: client_da,
      leafs: MapSet.new([global_genesis_block]),
      votes: %{}, #Key => Value:  PBlock => Set{int}
      current_epoch_proposal: nil,
      global_genesis_block: global_genesis_block
    }
  end

  @spec isnotarized(%PClient{}, %PBlock{}, non_neg_integer()) :: boolean()
  def isnotarized(client, block, n) do
    cond do
      #if the current block is the genesis block: return true
      block == client.global_genesis_block -> true
      #if length of the votes for of the client for block c are atleast n * 2/3: return true
      MapSet.size(client.votes) >= ((n * 2) / 3) -> true
      true -> false
    end
  end

  @spec lastnotarized(%PClient{}, %PBlock{}, non_neg_integer()) :: %PBlock{}
  def lastnotarized(client, block, n) do
    #while the the block for a client is not notarized, we go up in the blockchain
    if isnotarized(client, block, n) do
      block
    else
      lastnotarized(client, block.parent, n)
    end
  end

  #this is a helper function for the tip function
  @spec tip_helper(%PClient{}, list(), %PBlock{}, non_neg_integer(), non_neg_integer()) :: %PBlock{}
  defp tip_helper(client, leafs, best_block, best_depth, n) do
    if length(leafs) == 0 do
      best_block
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
  @spec tip(%PClient{}, non_neg_integer()) :: %PBlock{}
  def tip(client, n) do
    best_block = client.global_genesis_block
    best_depth = Utilities.depth(best_block)
    leafs = MapSet.to_list(client.leafs)
    #travese through all leafs and find the one with the maximum depth
    tip_helper(client, leafs, best_block, best_depth, n)
  end

  @spec finalizedtip_helperwhile(%PClient{}, list(), %PBlock{}, non_neg_integer(), non_neg_integer()) :: {%PBlock{}, non_neg_integer()}
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
  @spec finalizedtip_helper(%PClient{}, list(), %PBlock{}, non_neg_integer(), non_neg_integer()) :: %PBlock{}
  def finalizedtip_helper(client, leafs, best_block, best_depth, n) do
    if length(leafs) == 0 do
      best_block
    else
      head = hd(leafs)
      tail = tl(leafs)
      {best_block, best_depth} = finalizedtip_helperwhile(client, head, best_block, best_depth, n)
      finalizedtip_helper(client, tail, best_block, best_depth, n)
    end
  end

  #this function returns the finlized tip block in the longest chain of the blockchain
  @spec finalizedtip(%PClient{}, non_neg_integer()) :: %PBlock{}
  def finalizedtip(client, n) do
      best_block = client.global_genesis_block
      best_depth = Utilities.depth(best_block)
      leafs = MapSet.to_list(client.leafs)
      leafs = Enum.sort_by(leafs, fn x -> Utilities.depth(x) end)
      leafs = Enum.reverse(leafs)
      #travese through all leafs
      finalizedtip_helper(client, leafs, best_block, best_depth, n)
  end


  #This function returns the ledger
  @spec ledger(%PClient{}, non_neg_integer()) :: list(String.t())
  def ledger(client, n) do
    Utilities.ledger(finalizedtip(client, n))
  end

  #this function is a helper function for the allblocks function
  @spec allblocks_helper(%MapSet{}) :: %MapSet{}
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
  @spec allblocks(%PClient{}) :: %MapSet{}
  def allblocks(client) do
    leafs = MapSet.to_list(client.leafs)
    allblocks_helper(leafs)
  end


  #slot helper function
  @spec slot_helper(%PClient{},  non_neg_integer(), list(), non_neg_integer()) :: %PClient{}
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
          client = %{client | leafs: updated_leafs}
          client = %{client | votes: Map.put(client.votes, msg.block, MapSet.new())}
          #update current_epoch_proposal
          client =
            if msg.block.epoch ==  PBlock.epoch(t, bft_delay) and client.current_proposal == nil do
              %{client | current_proposal: msg.block}
            else
              client
            end
          slot_helper(client, t, tl(msg_in), bft_delay)
        else
          slot_helper(client, t, tl(msg_in), bft_delay)
        end
      client
    end
  end

  @spec slot_vote_helper(%PClient{}, list()) :: %PClient{}
  def slot_vote_helper(client, msgs_in) do
    if length(msgs_in) == 0 do
      client
    else
      msg = hd(msgs_in)
      if msg == %PMsgVote{} do
        updated_votes = Map.put(client.votes, msg.block, msg.id)
        client = %{client | votes: updated_votes}
        slot_vote_helper(client, tl(msgs_in))
      else
        slot_vote_helper(client, tl(msgs_in))
      end
    end
  end

  @spec slot!(%PClient{}, non_neg_integer(), list(), list(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {%PClient{}, list()}
  def slot!(client, t, msgs_out, msgs_in, bft_delay, n, k) do
    #update proposal
    client = slot_helper(client, t, msgs_in, bft_delay)
    #update votes
    client = slot_vote_helper(client, msgs_in)
    {client, msgs_out} =
    if rem(t, (2 * bft_delay)) == 0 do
      client = %{client | current_epoch_proposal: nil}
      msgs_out =
      if PBlock.leader(t, n, bft_delay) == client.id do
        new_pblock = PBlock.new(tip(client, n), PBlock.epoch(t, bft_delay), DAClient.confirmedtip(client.client_da, k))
        msgs_out ++ [PMsgProposal.new(t, client.id, new_pblock)]
      else
        msgs_out
      end
      {client, msgs_out}
    else
      msgs_out =
      if  rem(t, (2 * bft_delay)) == bft_delay and client.current_epoch_proposal != 0 do
        msgs_out ++ [PMsgVote.new(t, client.id, client.current_epoch_proposal)]
      else
        msgs_out
      end
      {client, msgs_out}
    end
    {client, msgs_out}
  end
end
