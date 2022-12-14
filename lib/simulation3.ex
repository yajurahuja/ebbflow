defmodule DPSimulation do

	defstruct(
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

		validatorsAwake: nil,
		validatorsAsleep: nil,

		part1Validators: nil,
		part2Validators: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil,

		genesisDA: nil,
		genesisP: nil

	)

	@spec newConfiguration(non_negative_integer(), non_negative_integer()) :: %DPSimulation{}
	def newConfiguration(n, f) do
		validators = for id <- 1..n, do (if id <= (n-f) do %HonestValidator(id) else %AdversarialValidator(id) end)
		%%DPSimulation{
			validators: validators,

			validatorsHonest: for id <- 1..(n-f), do id,
			validatorsAdversarial: for id <- (n-f+1)..n, do id,

			validatorsAwake: for id <- 1..n, do id,
			validatorsAsleep: [],

			validatorsPart1: for id <- 1..(n-f)*4/5, do id,
			validatorsPart2: for id <- ((n-f)*4/5+1)..(n-f), do id,

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators, {v.id, []}),

			livenessPhase: []

			genesisDA: genesisDA,
			genesisP: PBlock.genesis(genesisDA)
		}
	end

	@spec shuffleAwake(%DPSimulation{}) :: %DPSimulation{}
	def shuffleAwake(config) do
		%{config | validatorsAwake: shuffle(config.validatorsAwake)}
	end

	@spec shuffleAsleep(%DPSimulation{}) :: %DPSimulation{}
	def shuffleAsleep(config) do
		%{config | validatorsAsleep: shuffle(config.validatorsAsleep)}
	end

	@spec popAwake(%DPSimulation{}) :: %DPSimulation{}
	def popAwake(config) do
		%{config | validatorsAwake: List.tail(config.validatorsAwake)}
	end

	@spec popAsleep(%DPSimulation{}) :: %DPSimulation{}
	def popAsleep(config) do
		%{config | validatorsAsleep: List.tail(config.validatorsAsleep)}
	end

	@spec pushAwake(%DPSimulation{}, non_neg_integer())
		:: %DPSimulation{}
	def pushAwake(config, validatorId) do
		%{config | validatorsAwake: config.validatorsAwake ++ [validatorId]}
	end
	@spec pushAsleep(%DPSimulation{}, non_neg_integer())
		:: %DPSimulation{}
	def pushAsleep(config, validatorId) do
		%{config | validatorsAsleep: config.validatorsAsleep ++ [validatorId]}
	end

	@spec pushLivenessPhase(%DPSimulation{},
		{non_neg_integer(), non_neg_integer(), non_neg_integer()})
			:: %DPSimulation{}
	def pushLivenessPhase(config, phase) do
		%{config | livenessPhase: config.livenessPhase ++ [phase]}
	end

	# Puts an honest validator to sleep, or wakes it up, or does nothing.
	@spec daTick(%DPSimulation{}) :: %DPSimulation{}
	def daTick(config) do
		:rand.seed(config.rngDa)
		dir =
			cond do
				length(awake) == (2 * config.f) + 1 -> Enum.random([:toawake, :nothing])
				length(awake) == (config.n-config.f) -> Enum.random([:nothing, :toasleep])
				_ -> Enum.random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake -> popAsleep(pushAwake(config, head(config.validatorsAsleep)))
			dir == :toasleep -> popAwake(pushAsleep(config, head(config.validatorsAwake)))
			_ -> config
		end
	end

	# Replaces validator object having given id.
	@spec replaceValidator(%DPSimulation{}, non_neg_integer(), validator()) :: %DPSimulation{}
	def replaceValidator(config, validatorId, newValidator) do
		%{config | validators: map(config.validators, fn x -> (if x.id == validatorId, do: newValidator, else: x end))}
	end


	def missed_messages(config, msgs_out, v_id) do
		cond do
			v_id == length(config.validators) -> config
			Utilities.checkMembership(v_id, config.validatorsAwake) ->
				validator = Enum.at(Enum.filter(config.validators, fn x -> x.id == v_id end), 0)
				#TODO: fix the slot function
				config = %{config | msgs_missed: Map.put(config.msgs_missed, v_id, [])}
				missed_messages(config, msgs_out, v_id + 1)
			true ->
				updated_msgs_missed = Map.put(config.msgs_missed, v_id, config.msgs_missed[v_id] ++ config.msgs_in)
				config = %{config | msgs_missed: updated_msgs_missed}
				missed_messages(config, msgs_out, v_id + 1)
		end
	end


	def runSimulation(config, t) do

		cond do
			t == config.tEnd + 1 -> config
			_ ->
				config = daTick(config)

				config = %{config | msgsInflight: Map.put(config.msgsInflight, t + config.delta, [])}
				msgs_out = Map.get(config.msgsInflight, t + config.delta, [])
				msgs_in = Map.get(config.msgsInflight, t, [])

				config = missed_messages(config, msgs_out, 1) #v_id iterates from 1..n

				{l_LP, l_LDA} =
					if rem(t, 15) == 0 do
						l_LP = Enum.min(Enum.map(validatorsAwake, fn x -> length(HonestValidator.lp(x)) - 1 end))
						l_LDA = Enum.min(Enum.map(validatorsAwake, fn x -> length(HonestValidator.lda(x)) - 1 end))
						#TODO: print the l_LP, l_LDA
						{l_LP, l_LDA}
					else
						{nil, nil}
					end
				runSimulation(config, t + 1)
		end
	end
end
