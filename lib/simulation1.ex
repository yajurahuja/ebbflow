# Network parition simulation
defmodule NPSimulation do

  @type validator() :: %HonestValidator{} | %AdversarialValidator{}

  import Enum

	defstruct(
		#network simulation
		second: 1,
		minute: 60,
		hour: 3600,

		delta: 1,
		tEnd: 3600,
    tPartitions: [{600, 1200}, {1800, 2700}],

		#adversarial/honest validators
		n: nil,
		f: nil,

		#da params
		lambda: 0.1,
		k: 20,

		#p params
		deltaBft: 5,

		rngDa: nil,

		validators: nil,

		validatorsA: nil,
		validatorsB: nil,

		msgsInflightA: nil,
    msgsInflightB: nil

	)

  @spec new(non_neg_integer(), non_neg_integer()) :: %NPSimulation{}
	def new(n, f) do
		genesisDA = DABlock.genesis()
		genesisP = PBlock.genesis(genesisDA)
		validators =
			for id <- 0..(n-1) do
				if id < (n-f) do
					HonestValidator.new(id, genesisDA, genesisP)
				else
					# IO.puts(id)
					AdversarialValidator.new(id, genesisDA, genesisP)
				end
			end
		%NPSimulation{
			n: n,
			f: f,

			rngDa: MersenneTwister.init(2121+1),

			validators: validators,

			validatorsA: for id <- 0..round((n-f)/3*2-1) do id end,
			validatorsB: for id <- round((n-f)/3*2)..(n-f-1) do id end,

			msgsInflightA: Map.new(),
			msgsInflightB: Map.new(),

		}
	end

  def honest?(id, config) do
    id < (config.n-config.f)
  end

  @spec getpartition(%NPSimulation{}, non_neg_integer()) :: {boolean(), non_neg_integer()}
  def getpartition(config, t) do
    {start0, end0} = at(config.tPartitions, 0)
    {start1, end1} = at(config.tPartitions, 1)

    cond do
      start0 <= t and t < end0 ->
        {true, 0}
      start1 <= t and t < end1 ->
        {true, 1}
      true -> {false, -1}
    end
  end

  @spec ispartitioned(%NPSimulation{}, non_neg_integer()) :: boolean()
  def ispartitioned(config, t) do
    elem(getpartition(config, t), 0)
  end

  @spec logTPartition(%NPSimulation{}, non_neg_integer()) :: list(any())
  def logTPartition(config, t) do
    config.tPartitions
    |> with_index
    |> each(fn x ->
      {{tPartStart, tPartEnd}, i} = x
      case t do
        tPartStart ->
          IO.puts("# t=#{t}: start of partition #{i}")
        tPartEnd ->
          IO.puts("# t=#{t}: end of partition #{i}")
      end
    end
    )
  end

  # Put new value in msgsInflight[t]
	@spec modifyInflightMessagesA(%NPSimulation{}, non_neg_integer(), validator()) :: %NPSimulation{}
  def modifyInflightMessagesA(config, t, value) do
    %{config | msgsInflightA:  Map.put(config.msgsInflightA, t, value)}
  end

  @spec modifyInflightMessagesB(%NPSimulation{}, non_neg_integer(), validator()) :: %NPSimulation{}
  def modifyInflightMessagesB(config, t, value) do
    %{config | msgsInflightB:  Map.put(config.msgsInflightB, t, value)}
  end

  def getDelivery(config, t) do
    if ispartitioned(config, t) do
      tPartEnd = elem(at(config.tPartitions, elem(getpartition(config, t), 1)), 1)
      t_delivery_inter = Kernel.max(t + config.delta, tPartEnd)
      t_delivery_intra = t + config.delta

      {t_delivery_inter, t_delivery_intra}
    else
      t_delivery_inter = t + config.delta
      t_delivery_intra = t + config.delta

      {t_delivery_inter, t_delivery_intra}
    end
  end

  def log_ledger_lengths(config, t) do
    # log ledger lengths
    l_Lp_A = config.validatorsA
    |> map(fn v -> length(HonestValidator.lp(at(config.validators, v), config.n))-1 end)
    |> min()
    l_Lp_B = config.validatorsB
    |> map(fn v -> length(HonestValidator.lp(at(config.validators, v), config.n))-1 end)
    |> min()
    l_Lda_A = config.validatorsA
    |> map(fn v -> length(HonestValidator.lda(at(config.validators, v), config.n, config.k))-1 end)
    |> min()
    l_Lda_B = config.validatorsB
    |> map(fn v -> length(HonestValidator.lda(at(config.validators, v), config.n, config.k))-1 end)
    |> min()
    l_Lp = Kernel.min(l_Lp_A, l_Lp_B)
    l_Lda = Kernel.min(l_Lda_A, l_Lda_B)

    IO.puts("#{t/config.second} #{l_Lp} #{l_Lp_A} #{l_Lp_B} #{l_Lda} #{l_Lda_A} #{l_Lda_B}")
    # @show t/second l_Lp l_Lp_A l_Lp_B l_Lda l_Lda_A l_Lda_B
  end

  @spec runSimulation(%NPSimulation{}, non_neg_integer()) :: %NPSimulation{}
	def runSimulation(config, t) do
    cond do
			t == config.tEnd -> config
      true ->
        # logTPartition(config, t)

        # prepare msg queues
        msgs_out_A = []
        msgs_out_B = []
        msgs_in_A = Map.get(config.msgsInflightA, t, [])
        msgs_in_B = Map.get(config.msgsInflightB, t, [])

        # compute validator actions for this slot
        for v <- config.validatorsA do
          # TODO: slot!(v, t, msgs_out_A, msgs_in_A)
          msgs_out_A = HonestValidator.slot(at(config.validators, v), t, msgs_out_A, msgs_in_A, config)
        end

        ## CHAITANYA: v is in an integer, it needs to be a validator object
        ## Also, Honest validator updates the validator object, and returns
        ## msgs_out_B
        for v <- config.validatorsB do
          # TODO: slot!(v, t, msgs_out_B, msgs_in_B)
          msgs_out_B = HonestValidator.slot(at(config.validators, v), t, msgs_out_B, msgs_in_B, config)
        end

        # msg delivery, respecting periods of intermittent partitions
        {t_delivery_inter, t_delivery_intra} = getDelivery(config, t)

        config = modifyInflightMessagesA(config, t_delivery_inter, Map.get(config.msgsInflightA, t_delivery_inter, []))
        config = modifyInflightMessagesB(config, t_delivery_inter, Map.get(config.msgsInflightB, t_delivery_inter, []))
        config = modifyInflightMessagesA(config, t_delivery_intra, Map.get(config.msgsInflightA, t_delivery_intra, []))
        config = modifyInflightMessagesB(config, t_delivery_intra, Map.get(config.msgsInflightB, t_delivery_intra, []))

        config = modifyInflightMessagesA(config, t_delivery_inter, Map.fetch!(config.msgsInflightA, t_delivery_inter) ++ msgs_out_B)
        config = modifyInflightMessagesB(config, t_delivery_inter, Map.fetch!(config.msgsInflightB, t_delivery_inter) ++ msgs_out_A)
        config = modifyInflightMessagesA(config, t_delivery_intra, Map.fetch!(config.msgsInflightA, t_delivery_intra) ++ msgs_out_A)
        config = modifyInflightMessagesB(config, t_delivery_intra, Map.fetch!(config.msgsInflightB, t_delivery_intra) ++ msgs_out_B)

        if rem(t, 15*config.second) == 0 do
          log_ledger_lengths(config, t)
        end

        runSimulation(config, t+1)
    end
  end
end
