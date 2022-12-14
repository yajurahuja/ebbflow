defmodule Validator do

  @type msg() :: %DAMsgNewBlock{} | %PMsgProposal{} | %PMsgVote{}

  @spec sanitizeHelper(list(String.t()), list(String.t())) :: list(String.t())
  defp sanitizeHelper(list, out) do
    case list do
      [] -> out
      [head | tail] -> 
        if Utilities.checkMembership(head, out) do
          sanitizeHelper(tail, out)
        else
          sanitizeHelper(tail, out++[head])
        end
    end
  end

  @spec sanitize(list(String.t())) :: list(String.t())
  def sanitize(list) do
    sanitizeHelper(list, [])
  end

  @spec flattenList(list(list(String.t())), list(String.t())) :: list(String.t())
  defp flattenList(list, out) do
    case list do
      [] -> out
      [head | tail] -> flattenList(tail, out ++ head)
    end
  end
end

defmodule HonestValidator do
  defstruct(
    id: nil,
    client_da: nil,
    client_p: nil
  )

  #creates a new Honest Validator
  @spec new(integer(), %DABlock{}, %PBlock{}) :: %HonestValidator{}
  def new(id, genesisDA, genesisP) do
    client_da = DAClient.new(id, genesisDA)
    client_p = PClient.new(id, client_da, genesisP)
    %HonestValidator{
      id: id,
      client_da: client_da,
      client_p: client_p
    }
  end

  @spec slot(%HonestValidator{}, non_neg_integer(), list(Validator.msg()), list(Validator.msg()), float()) :: {%HonestValidator{}, list(Validator.msg())}
  def slot(validator, t, msgs_out, msgs_in, config) do
    {client_da, msgs_out} = DAMsgNewBlock.slot!(validator.client_da, t, msgs_out, msgs_in, :honest, (config.lambda/config.n)/config.second)
    {client_p, msgs_out} = PClient.slot!(validator.client_p, t, msgs_out, msgs_in, config.bftDelay, config.n)

    {%{validator | client_da: client_da, client_p: client_p}, msgs_out}
  end

  @spec lp(%HonestValidator{}) :: list(String.t())
  def lp(validator) do
    Validator.sanitize(Validator.flattenList(
      Enum.map(validator.client_p, fn x -> Utilities.ledger(x) end), 
      []))
  end

  @spec lda(%HonestValidator{}) :: list(String.t())
  def lda(validator) do
    Validator.sanitize(lp(validator) ++ Utilities.ledger(validator.client_da))
  end
end

defmodule AdversarialValidator do
  defstruct(
    id: nil,
    client_da: nil
  )

  @spec new(integer(), %DABlock{}, %PBlock{}) :: %AdversarialValidator{}
  def new(id, genesisDA, _) do
    client_da = DAClient.new(id, genesisDA)
    %AdversarialValidator{
      id: id,
      client_da: client_da
    }
  end

  @spec slot(%AdversarialValidator{}, non_neg_integer(), list(Validator.msg()), list(Validator.msg())) :: list(Validator.msg())
  def slot(_, _, msgs_out, _) do
    msgs_out
  end

  @spec findMaxBlockDepth(list(Validator.msg()), non_neg_integer()) :: non_neg_integer()
  defp findMaxBlockDepth(msgs, maxVal) do
    case msgs do
      [] -> maxVal
      [head | tail] -> 
        case head do
          %DAMsgNewBlock{} -> findMaxBlockDepth(tail, Enum.max(maxVal, Utilities.depth(head.block)))
          _ -> findMaxBlockDepth(tail, maxVal)
        end
    end
  end

  @spec slot(%AdversarialValidator{}, non_neg_integer(), non_neg_integer(), 
    list(Validator.msg()), list(Validator.msg()), list(Validator.msg()), 
    list(Validator.msg()), float()) 
      :: {%AdversarialValidator{}, list(Validator.msg()), 
        list(Validator.msg())}
  def slot(validator, n, t, msgs_out_private_adversarial, msgs_out_rush_honest, msgs_in, msgs_in_rush_honest, prob_pos_mining_success_per_slot) do
    {client_da, msgs_out_private_adversarial} = DAMsgNewBlock.slot!(validator, t, msgs_out_private_adversarial, msgs_in ++ msgs_in_rush_honest, :adversarial, prob_pos_mining_success_per_slot)

    validator = %{validator | client_da: client_da}

    if validator.id == n do
      d = findMaxBlockDepth(msgs_in_rush_honest, -1)

      if d > -1 do
        blk = DAClient.tip(validator.client_da)

        if Utilities.depth(d) < d do
          {validator, msgs_out_private_adversarial, msgs_out_rush_honest}
        else
          {validator, msgs_out_private_adversarial, msgs_out_rush_honest ++ [DAMsgNewBlock.new(t, validator.client_da.id, blk)]}
        end
      else
        {validator, msgs_out_private_adversarial, msgs_out_rush_honest}
      end
    else
      {validator, msgs_out_private_adversarial, msgs_out_rush_honest}
    end
  end

  @spec lda(%AdversarialValidator{}) :: list(String.t())
  def lda(validator) do
    Validator.sanitize(Utilities.ledger(validator.client_da))
  end

end
