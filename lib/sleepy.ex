defmodule DABlock do
  defstruct(
    parent: nil,
    payload: nil
  )

  @spec new(%DABlock{} | nil, list(String.t())) ::%DABlock{}
  def new(parent, payload) do
    %DABlock{
      parent: parent,
      payload: payload
    }
  end

  @spec genesis() :: %DABlock{}
  def genesis() do
    new(nil, "da-genesis")
  end
end

defmodule DAClient do
  defstruct(
    id: nil,
    leafs: nil,
    rng_mining: nil,
    genesis: nil
  )

  @spec new(non_neg_integer(), %DABlock{}) :: %DAClient{}
  def new(id, genesisDA) do
    %DAClient{
      id: id,
      leafs: MapSet.new([genesisDA]),
      rng_mining: MersenneTwister.init(2342 + id),
      genesis: genesisDA
    }
  end

  @spec tip(%DAClient{}) :: %DABlock{}
  def tip(client) do
    leafs = Enum.sort_by(MapSet.to_list(client.leafs),
      &{Utilities.depth(&1), String.starts_with?(&1.payload, "adversarial")}, :desc)
    hd(leafs)
  end

  @spec confirmedtip_helper(%DAClient{}, %DABlock{}, non_neg_integer()) :: %DABlock{}
  defp confirmedtip_helper(client, block, k) do
    cond do
      k == 0 or block == client.genesis ->
        block
      true ->
        block = block.parent
        confirmedtip_helper(client, block, k-1)
    end
  end

  @spec confirmedtip(%DABlock{}, non_neg_integer()) :: %DABlock{}
  def confirmedtip(client, k) do
    b = tip(client)
    confirmedtip_helper(client, b, k)
  end


  @spec ledger(%DAClient{}, non_neg_integer()) :: list(String.t())
  def ledger(client, k) do
    Utilities.ledger(confirmedtip(client, k))
  end

  @spec allblocks(%DABlock{}) :: %MapSet{}
  def allblocks(client) do
    MapSet.to_list(client.leafs)
    |> Enum.map(fn l -> Utilities.chain(l) end)
    |> List.flatten()
    |> MapSet.new()
  end

end

defmodule DAMsgNewBlock do
  defstruct(
    t: 0,
    id: 0,
    block: nil
  )

  @spec new(non_neg_integer(), non_neg_integer(), %DABlock{}) :: %DAMsgNewBlock{}
  def new(t, id, block) do
    %DAMsgNewBlock{t: t, id: id, block: block}
  end

  @spec daMsgNewBlock?(%DAMsgNewBlock{}) :: boolean()
  defp daMsgNewBlock?(%DAMsgNewBlock{}) do
    true
  end

  @spec daMsgNewBlock?(any()) :: boolean()
  defp daMsgNewBlock?(_) do
    false
  end

  @spec slot!(%DABlock{}, non_neg_integer(), list(), list(), any(), any()) :: {%DAClient{}, list()}
  def slot!(client, t, msgs_out, msgs_in, role, prob_pos_mining_success_per_slot) do
    daMsgs = Enum.filter(msgs_in, fn x -> daMsgNewBlock?(x) end)
    diff = daMsgs
    |> Enum.map(fn x -> x.block.parent end)
    |> MapSet.new()

    additions = daMsgs
    |> Enum.map(fn x -> x.block end)
    |> MapSet.new()

    client = %{client | leafs: MapSet.difference(client.leafs, diff)}
    client = %{client | leafs: MapSet.union(client.leafs, additions)}

    msgs_out = 
      if elem(MersenneTwister.nextUniform(client.rng_mining), 0) <= prob_pos_mining_success_per_slot do
        if role == :honest do
          new_dablock = DABlock.new(DAClient.tip(client), "t=#{t},id=#{client.id}")
          MapSet.put(msgs_out, DAMsgNewBlock.new(t, client.id, new_dablock))
        else
          new_dablock = DABlock.new(DAClient.tip(client), "adversarial:t=#{t},id=#{client.id}")
          MapSet.put(msgs_out, DAMsgNewBlock.new(t, client.id, new_dablock))
        end
      end

    {client, msgs_out}
  end

end
