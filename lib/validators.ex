defmodule HonestValidator do
  defstruct(
    id: nil,
    client_da: nil,
    client_p: nil
  )

  #creates a new Honest Validator
  def new(id) do
    client_da = DAClient.new(id)
    client_p = PClient.new(id, client_da)
    %HonestValidator{
      id: id,
      client_da: client_da,
      client_p: client_p
    }
  end

  def slot(validator, t, msgs_out, msgs_in) do
    #TODO: message passing functions and slotting
  end

  def sanitize(lst) do
    out = []
    #TODO: remove duplicates
    #does the sanitation happen in order
    #if not, will use MapSet and convert back to list
    out
  end

  def lp(validator) do
    #TODO:
  end

  def lda(validator) do
    sanitize(lp(validator) ++ Utilities.ledger(validator.client_da))
  end
end

defmodule AdversarialValidator do
  defstruct(
    id: nil,
    client_da: nil
  )

  def new(id) do
    client_da = DAClient.new(id)
    %AdversarialValidator{
      id: id,
      client_da: client_da
    }
  end

  def lda(validator) do
    HonestValidator.sanitize(Utilities.ledger(validator.client_da))
  end

end
