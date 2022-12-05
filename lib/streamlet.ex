defmodule PBlock do

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
    new_PBlock(nil, -1, DABlock.genesis())
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
      leafs: nil, #TODO: set leafs to be the genesuis block
      votes: nil, #TODO: set votes to be a dictionary
      current_epochs_proposal: nil
    }
  end

  def isnotarized(client, block) do
    notarized =
      if block == genesis_block do #TODO: fix genesis block
        true
      else
        false
      end
    #if length of the votes for of the client for block c are atleast n * 2 /3: return true
    notarized
  end

  def lastnotarized(client, block) do
    #while the the block for a client is not notarized, we go up in the blockchain
    block
  end

end
