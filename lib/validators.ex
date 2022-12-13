defmodule Validator do

  @type msg() :: %DAMsgNewBlock{} | %PMsgProposal{} | %PMsgVote{}

  @spec sanitizeHelper(list(string()), list(string())) :: list(string())
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

  @spec sanitize(list(string())) :: list(string())
  def sanitize(list) do
    sanitizeHelper(list, [])
  end

  @spec flattenList(list(list(string())), list(string)) :: list(string())
  defp flattenList(list, out) do
    case list do
      [] -> out
      [head | tail] -> (list, out ++ head)
    end
  end

  defmodule HonestValidator do
    defstruct(
      id: nil,
      client_da: nil,
      client_p: nil
    )

    #creates a new Honest Validator
    @spec new(integer()) :: %HonestValidator{}
    def new(id) do
      client_da = DAClient.new(id)
      client_p = PClient.new(id, client_da)
      %HonestValidator{
        id: id,
        client_da: client_da,
        client_p: client_p
      }
    end

    @spec slot(%HonestValidator{}, non_neg_integer(), list(msg()), list(msg())) :: {%HonestValidator{}, list(msg())}
    def slot(validator, t, msgs_out, msgs_in) do
      {client_da, msgs_out} = DAClient.slot(v.client_da, t, msgs_out, msgs_in, :honest)
      {client_p, msgs_out} = PClient.slot(v.client_p, t, msgs_out, msgs_in)

      {%{validator | client_da: client_da, client_p: client_p}, msgs_out}
    end

    @spec lp(%HonestValidator{}) :: list(string)
    def lp(validator) do
      Validator.sanitize(Validator.flattenList(Enum.map(validator.client_p, 
        fn x -> Utilities.ledger(x) end), []))
    end

    @spec lda(%HonestValidator{}) :: list(string)
    def lda(validator) do
      Validator.sanitize(lp(validator) ++ Utilities.ledger(validator.client_da))
    end
  end

  defmodule AdversarialValidator do
    defstruct(
      id: nil,
      client_da: nil
    )

    @spec new(integer()) :: %AdversarialValidator{}
    def new(id) do
      client_da = DAClient.new(id)
      %AdversarialValidator{
        id: id,
        client_da: client_da
      }
    end

    @spec slot(%AdversarialValidator{}, non_neg_integer(), list(msg()), list(msg())) :: list(msg())
    def slot(validator, t, msgs_out, msgs_in) do
      msgs_out
    end

    @spec findMaxBlockDepth(list(msg()), non_neg_integer()) :: non_neg_integer()
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

    @spec slot(%AdversarialValidator{}, non_neg_integer(), non_neg_integer(), list(msg()), list(msg()), list(msg()), list(msg())) :: {%AdversarialValidator{}, list(msg()), list(msg())}
    def slot(validator, n, t, msgs_out_private_adversarial, msgs_out_rush_honest, msgs_in, msgs_in_rush_honest) do
      {client_da, msgs_out_private_adversarial} = DAClient.slot(validator, t, msgs_out_private_adversarial, msgs_in ++ msgs_in_rush_honest, :adversarial)

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

    @spec lda(%AdversarialValidator{}) :: list(string())
    def lda(validator) do
      Validator.sanitize(Utilities.ledger(validator.client_da))
    end

  end
end
