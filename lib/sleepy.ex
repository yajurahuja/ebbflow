defmodule DABlock do
  defstruct(
    parent: nil,
    payload: nil
  )

  def new(parent, payload) do
    %DABlock{
      parent: parent,
      payload: payload
    }
  end

  def genesis() do
    new(nil, "da-genesis")
  end
end

defmodule DAClient do
  defstruct(
    id: nil,
    leafs: MapSet.new([DABlock.genesis()]),
    rng_mining: nil
  )

  def new(id) do
    %DAClient{
      id: id,
      rng_mining: MersenneTwister.init(2342 + id)
    }
  end

  def tip(client) do
    leafs = Enum.sort_by(MapSet.to_list(client.leafs),
      &{Utilities.depth(&1), String.starts_with?(&1.payload, "adversarial")}, :desc)
    hd(leafs)
  end

  defp confirmedtip_helper(block, k) do
    cond do
      k == 0 or block == DABlock.genesis() ->
        block
      true ->
        block = block.parent
        confirmedtip_helper(block, k-1)
    end
  end

  def confirmedtip(client, k) do
    b = tip(client)
    confirmedtip_helper(b, k)
  end

  def ledger(client, k) do
    confirmedtip(client, k)
  end

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

  def new(t, id, block) do
    %DAMsgNewBlock{t: t, id: id, block: block}
  end

  defp daMsgNewBlock?(%DAMsgNewBlock{}) do
    true
  end

  defp daMsgNewBlock?(_) do
    false
  end

  def slot!(client, t, msgs_out, msgs_in, role \\ :honest, prob_pos_mining_success_per_slot) do
    daMsgs = Enum.filter(msgs_in, fn x -> daMsgNewBlock?(x) end)
    diff = daMsgs
    |> Enum.map(fn x -> x.block.parent end)
    |> MapSet.new()

    additions = daMsgs
    |> Enum.map(fn x -> x.block end)
    |> MapSet.new()

    client = %{client | leafs: MapSet.difference(client.leafs, diff)}
    client = %{client | leafs: MapSet.union(client.leafs, additions)}

    if elem(MersenneTwister.nextUniform(client.rng_mining), 0) <= prob_pos_mining_success_per_slot do
      if role == :honest do
        new_dablock = DABlock.new(DAClient.tip(client), "t=#{t},id=#{client.id}")
        MapSet.put(msgs_out, DAMsgNewBlock.new(t, client.id, new_dablock))
      else
        new_dablock = DABlock.new(DAClient.tip(client), "adversarial:t=#{t},id=#{client.id}")
        MapSet.put(msgs_out, DAMsgNewBlock.new(t, client.id, new_dablock))
      end
    end
  end

end
