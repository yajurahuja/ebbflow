defmodule DPSimulation do

	@type validator() :: %HonestValidator{} | %AdversarialValidator{}

	import Enum

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
		deltaBft: 5,

		rngDa: nil,

		validators: nil,

		validatorsHonest: nil,
		validatorsAdversarial: nil,

		validatorsAwake: nil,
		validatorsAsleep: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil

	)

	@spec new(non_neg_integer(), non_neg_integer()) :: %DPSimulation{}
	def new(n, f) do
		genesisDA = DABlock.genesis()
		genesisP = PBlock.genesis(genesisDA)
		validators =
			for id <- 0..(n-1) do
				if id <= (n-f-1) do
					HonestValidator.new(id, genesisDA, genesisP)
				else
					AdversarialValidator.new(id, genesisDA, genesisP)
				end
			end
		IO.puts("t l_Lp l_Lda l_awake l_asleep")
		%DPSimulation{
			n: n,
			f: f,

			rngDa: MersenneTwister.init(2121+1),

			validators: validators,

			validatorsHonest: for id <- 0..(n-f-1) do id end,
			validatorsAdversarial: for id <- (n-f)..(n-1) do id end,

			validatorsAwake: for id <- 0..(floor(4 * (n-f)/5)) do id end,
			validatorsAsleep: for id <- ((floor(4 * (n-f)/5)) + 1)..(n-f-1) do id end,

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators do {v.id, []} end),

			livenessPhase: []

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
		%{config | validatorsAwake: tl(config.validatorsAwake)}
	end

	@spec popAsleep(%DPSimulation{}) :: %DPSimulation{}
	def popAsleep(config) do
		%{config | validatorsAsleep: tl(config.validatorsAsleep)}
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
		# :rand.seed(config.rngDa)
		# TODO seed
		dir =
			cond do
				length(config.validatorsAwake) == (2 * config.f) + 1 -> Enum.random([:toawake, :nothing])
				length(config.validatorsAwake) == (config.n-config.f) -> Enum.random([:nothing, :toasleep])
				true ->
					# IO.puts(inspect(config))
					random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake ->
				config = shuffleAsleep(config)
				popAsleep(pushAwake(config, hd(config.validatorsAsleep)))
			dir == :toasleep ->
				config = shuffleAwake(config)
				popAwake(pushAsleep(config, hd(config.validatorsAwake)))
			true -> config
		end
	end

	# Replaces validator object having given id.
	@spec replaceValidator(%DPSimulation{}, non_neg_integer(), validator())
		:: %DPSimulation{}
	def replaceValidator(config, validatorId, newValidator) do
		%{config | validators:
			map(config.validators,
				fn x ->
					if x.id == validatorId do
						newValidator
					else
						x
					end
				end)}
	end


	def missed_messages(config, msgs_out, msgs_in, v_id, t) do
		cond do
			v_id == length(config.validators) -> config
			Utilities.checkMembership(v_id, config.validatorsAwake) ->
				validator = Enum.at(Enum.filter(config.validators, fn x -> x.id == v_id end), 0)
				{validator, msgs_out} = HonestValidator.slot(validator, t, msgs_out, config.msgsMissed[v_id] ++ msgs_in, config)
				config = replaceValidator(config, v_id, validator)
				updated_msgsInflight = Map.put(config.msgsInflight, t + config.delta, msgs_out)
				config = %{config | msgsInflight: updated_msgsInflight}
				updated_msgs_missed = Map.put(config.msgsMissed, v_id, [])
				config = %{config | msgsMissed: updated_msgs_missed}
				missed_messages(config, msgs_out, msgs_in, v_id + 1, t)
			true ->
				updated_msgs_missed = Map.put(config.msgsMissed, v_id, config.msgsMissed[v_id] ++ msgs_in)
				config = %{config | msgsMissed: updated_msgs_missed}
				missed_messages(config, msgs_out, msgs_in, v_id + 1, t)
		end
	end


	def runSimulation(config, t) do

		cond do
			t == config.tEnd + 1 -> config
			true ->
				config = daTick(config)
				config = %{config | msgsInflight: Map.put(config.msgsInflight, t + config.delta, [])}
				msgs_out = Map.get(config.msgsInflight, t + config.delta, [])
				msgs_in = Map.get(config.msgsInflight, t, [])
				# IO.puts("msgs_out: #{inspect(msgs_out)} ")
				# IO.puts("msgs_in: #{inspect(msgs_in)} ")
				config = missed_messages(config, msgs_out, msgs_in, 0, t) #v_id iterates from 0..n-1

				{l_LP, l_LDA} =
					if rem(t, 15) == 0 do
						l_LP = Enum.min(Enum.map(config.validatorsAwake, fn x -> length(HonestValidator.lp(at(config.validators, x), config.n)) - 1 end))
						l_LDA = Enum.min(Enum.map(config.validatorsAwake, fn x -> length(HonestValidator.lda(at(config.validators, x), config.n, config.k)) - 1 end))
						#l_LP = Enum.map(config.validatorsAwake, fn x -> length(HonestValidator.lp(at(config.validators, x), config.n)) - 1 end)
						#l_LDA = Enum.map(config.validatorsAwake, fn x -> length(HonestValidator.lda(at(config.validators, x), config.n, config.k)) - 1 end)
						#TODO: print the l_LP, l_LDA
						IO.puts("#{inspect(t)} #{inspect(l_LP)} #{inspect(l_LDA)} #{inspect(length(config.validatorsAwake))} #{inspect(length(config.validatorsAsleep))}")
						{l_LP, l_LDA}
					else
						{nil, nil}
					end
				runSimulation(config, t + 1)
		end
	end
end
