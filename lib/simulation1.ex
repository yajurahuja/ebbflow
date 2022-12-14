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

		validatorsHonest: nil,
		validatorsAdversarial: nil,

		validatorsAwake: nil,

		validatorsPart1: nil,
		validatorsPart2: nil,

		msgsInflight1: nil,
    msgsInflight2: nil

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

			validatorsHonest: for id <- 0..(n-f-1) do id end,
			validatorsAdversarial: for id <- (n-f)..(n-1) do id end,

			validatorsAwake: for id <- 0..(n-f-1) do id end,

			validatorsPart1: for id <- 0..round((n-f)/3*2-1) do id end,
			validatorsPart2: for id <- round((n-f)/3*2)..(n-f-1) do id end,

			msgsInflight1: Map.new(),
			msgsInflight2: Map.new(),

		}
	end

  @spec getpartition(%NPSimulation{}, non_neg_integer()) :: {boolean(), non_neg_integer()}
  def getpartition(config, t) do
    {start0, end0} = Enum.at(config.tPartitions, 0)
    {start1, end1} = Enum.at(config.tPartitions, 1)

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
end
