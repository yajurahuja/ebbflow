defmodule PBlock do

  #import useful things
  #import MapSet #This is for the Set data structure
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

  def leader(t) do
    e = epoch(t, bft_delay)
    l = 1 #TODO: get random number
    l
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
      leafs: MapSet.new([PBlock.genesis()]), #TODO: set leafs to be the genesuis block
      votes: %{}, #Key => Value:  PBlock => Set{int}
      current_epochs_proposal: nil
    }
  end

  def isnotarized(client, block) do
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
  end

  #this function returns the tip block in the longest chain of the blockchain
  def tip(client) do
    best_block = PBlock.genesis()
    best_depth = depth(best_block)
    #for loop on all leafs of
  end
  def finalized_tip(client, blocks) do
      blocks = MapSet()

  end

  #this funciton returns all
end
