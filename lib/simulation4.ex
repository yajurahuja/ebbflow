defmodule OverviewSimulation do

	defstruct[
		#network simulation
		second: 1,
		minute: 60,
		hour: 3600,

		delta: 1,
		tEnd: 3600,
		tPartStart: 1400,
		tPartStop: 2000,

		#adversarial/honest validators
		n: nil,
		f: nil,

		#da params
		lambda: 0.1,
		k: 20,

		#p params
		deltaBft: 5

		rngDa = MersenneTwister.init(2121+1)

		validators: nil,

		validatorsHonest: nil,
		validatorsAdversarial: nil,

		awakeValidators: nil,
		asleepValidators: nil,

		part1Validators: nil,
		part2Validators: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil

	]

	@spec newConfiguration() :: %OverviewSimulation{}
	def newConfiguration(n, f) do 
		validators = for id <- 1..n, do (if id<= (n-f) do %HonestValidator(id) else %AdversarialValidator(id) end)
		%OverviewSimulation{
			validators: validators,
			
			validatorsHonest: Enum.slice(validators, 0, n-f),
			validatorsAdversarial: Enum.slice(validators, n-f, f),
			
			validatorsAwake: validators,
			validatorsAsleep: [],
			
			validatorsPart1: Enum.slice(validators, 0, (n-f)/2),
			validatorsPart2: Enum.slice(validators, (n-f)/2, (n-f)-(n-f)/2),

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators, {v, []}),

			livenessPhase: []
		}
	end

	def shuffleAwake(config) do
		%{config | awakeValidators: enum.shuffle(config.awakeValidators)}
	end

	def shuffleAsleep(config) do
		%{config | asleepValidators: enum.shuffle(config.asleepValidators)}
	end

	def popAwake(config) do
		%{config | awakeValidators: List.tail(config.awakeValidators)}
	end

	def popAsleep(config) do
		%{config | asleepValidators: List.tail(config.asleepValidators)}
	end

	def pushAwake(config, val) do
		%{config | awakeValidators: config.awakeValidators ++ [val]}
	end

	def pushAsleep(config, val) do
		%{config | asleepValidators: config.asleepValidators ++ [val]}
	end

	@spec daTick(%OverviewSimulation) :: %OverviewSimulation
	def daTick(config) do
		:rand.seed(config.rngDa)
		dir = 
			cond do
				List.length(awake) == 60 -> Enum.random([:toawake, :nothing])
				List.length(awake) == (config.n-config.f) -> Enum.random([:nothing, :toasleep])
				_ -> Enum.random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake -> popAsleep(pushAwake(config, head(config.asleepValidators)))
			dir == :toasleep -> popAwake(pushAsleep(config, head(config.awakeValidators)))
			_ -> config
		end
	end

	def runSimulation(config, time) do
		config = daTick(config)
	end


end





















