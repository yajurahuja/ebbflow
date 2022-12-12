defmodule DPSimulation do

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

	@spec newConfiguration() :: %DPSimulation{}
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

	def pushLivenessPhase(config, val) do
		%{config | livenessPhase: config.livenessPhase ++ [val]}
	end

	@spec daTick(%DPSimulation{}) :: %DPSimulation{}
	def daTick(config) do
		:rand.seed(config.rngDa)
		dir =
			cond do
				List.length(awake) == 2 * config.f + 1 -> Enum.random([:toawake, :nothing])
				List.length(awake) == (config.n-config.f) -> Enum.random([:nothing, :toasleep])
				_ -> Enum.random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake -> popAsleep(pushAwake(config, head(config.asleepValidators)))
			dir == :toasleep -> popAwake(pushAsleep(config, head(config.awakeValidators)))
			_ -> config
		end
	end

	def honestMsgManage(config, validators, msgsOutPart1, msgsOutPart2) do
		case validators do
			[] -> {config, msgsOutPart1, msgsOutPart2}
			[validator | tail] ->
				msgsIn = Map.get(config.msgsInAll)
				config =
					if Utilities.checkMembership(config.awakeValidators, validator) do
						msgsOut =
							if Utilities.checkMembership(config.validatorsPart1, validator) do
								msgsOutPart1
							else
								msgsOutPart2
							end
						HonestValidator.slot(validator, t, msgs_out, config.msgsMissed[validator] ++ msgsIn)
						%{config | msgsMissed: Map.drop(config.msgsMissed, validator)}
					else
						%{config | msgsMissed: Map.replace(config.msgsMissed, validator, config.msgsMissed[validator] ++ msgsIn)}
					end
				honestMsgManage(config, tail, msgsOutPart1, msgsOutPart2)
		end
	end

	def runSimulation(config, t) do
		config = daTick(config)

		config =
			if rem(t, 15*config.second) == 0 do
				case config.livenessPhaseStart do
					nil ->
						if List.length(config.awakeValidators) >= 67 do
							%{config | livenessPhaseStart = t}
						else
							config
						end
					_ ->
						if List.length(config.awakeValidators) < 67 or t == config.tEnd do
							config = pushLivenessPhase(config, {config.livenessPhaseStart, (config.livenessPhaseStart+t)/2, t})
							%{config | livenessPhaseStart = nil}
						else
							config
						end
				end
			else
				config
			end

		msgsInAll = Map.get(config.msgsInflight, t, Map.new())

		{config, msgsOutPart1, msgsOutPart2} = honestMsgManage(config, config.awakeValidators, [], [])

	end


end
