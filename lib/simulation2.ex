defmodule AdversarialSimulation do

  @type validator() :: %HonestValidator{} | %AdversarialValidator{}

  import Enum

	defstruct(
		#network simulation
		second: 1,
		minute: 60,
		hour: 3600,

		delta: 1,
		tEnd: 3600,
		tPartStart: 10*60,
		tPartStop: 30*60,

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

		validatorsPart1: nil,
		validatorsPart2: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil

	)

	@spec new(non_neg_integer(), non_neg_integer()) :: %AdversarialSimulation{}
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
		%AdversarialSimulation{
			n: n,
			f: f,

			rngDa: MersenneTwister.init(2121+1),

			validators: validators,

			validatorsHonest: for id <- 0..(n-f-1) do id end,
			validatorsAdversarial: for id <- (n-f)..(n-1) do id end,

			validatorsAwake: for id <- 0..(n-f-1) do id end,
			validatorsAsleep: [],

			validatorsPart1: for id <- 0..14 do id end,
			validatorsPart2: for id <- 15..(n-f-1) do id end,

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators do {v.id, []} end),

			livenessPhase: []

		}
	end

	@spec shuffleAwake(%AdversarialSimulation{}) :: %AdversarialSimulation{}
	def shuffleAwake(config) do
		%{config | validatorsAwake: shuffle(config.validatorsAwake)}
	end

	@spec shuffleAsleep(%AdversarialSimulation{}) :: %AdversarialSimulation{}
	def shuffleAsleep(config) do
		%{config | validatorsAsleep: shuffle(config.validatorsAsleep)}
	end

	@spec popAwake(%AdversarialSimulation{}) :: %AdversarialSimulation{}
	def popAwake(config) do
		%{config | validatorsAwake: tl(config.validatorsAwake)}
	end

	@spec popAsleep(%AdversarialSimulation{}) :: %AdversarialSimulation{}
	def popAsleep(config) do
		%{config | validatorsAsleep: tl(config.validatorsAsleep)}
	end

	@spec pushAwake(%AdversarialSimulation{}, non_neg_integer()) :: %AdversarialSimulation{}
	def pushAwake(config, validatorId) do
		%{config | validatorsAwake: config.validatorsAwake ++ [validatorId]}
	end
	@spec pushAsleep(%AdversarialSimulation{}, non_neg_integer()) :: %AdversarialSimulation{}
	def pushAsleep(config, validatorId) do
		%{config | validatorsAsleep: config.validatorsAsleep ++ [validatorId]}
	end

	@spec pushLivenessPhase(%AdversarialSimulation{},
		{non_neg_integer(), non_neg_integer(), non_neg_integer()}) :: %AdversarialSimulation{}
	def pushLivenessPhase(config, phase) do
		%{config | livenessPhase: config.livenessPhase ++ [phase]}
	end

	@spec getRandomList(list(), float()) :: any()
	def getRandomList(l, fl) do
		ind = trunc(fl*length(l))
		Enum.at(l, ind)
	end

	# Puts an honest validator to sleep, or wakes it up, or does nothing.
	@spec daTick(%AdversarialSimulation{}) :: %AdversarialSimulation{}
	def daTick(config) do
		{nextRand, newRng} = MersenneTwister.nextUniform(config.rngDa)
		config = %{config | rngDa: newRng}
		dir =
			cond do
				length(config.validatorsAwake) == 60 -> getRandomList([:toawake, :nothing], nextRand)
				length(config.validatorsAwake) == (config.n-config.f) -> getRandomList([:nothing, :toasleep], nextRand)
				true ->
					getRandomList([:toawake, :toasleep], nextRand)
			end

		cond do
			dir == :toawake ->
				config = shuffleAsleep(config)
				ind = hd(config.validatorsAsleep)
				popAsleep(pushAwake(config, ind))
			dir == :toasleep ->
				config = shuffleAwake(config)
				popAwake(pushAsleep(config, hd(config.validatorsAwake)))
			true -> config
		end
	end

	# Replaces validator object having given id.
	@spec replaceValidator(%AdversarialSimulation{}, non_neg_integer(), validator())
		:: %AdversarialSimulation{}
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

	# Computes honest awake validator actions for this slot.
	# Collects messages missed by asleep validators.
	# Set validatorIds to config.validatorsHonest.
	# msgsOutPart1 aggregagates msgs output by validatorsPart1.
	#		On initial call, it should be empty. Same for msgsOutPart2.
	@spec slotHonestMsgs(%AdversarialSimulation{}, non_neg_integer(), list(non_neg_integer()),
		list(Validator.msg()), list(Validator.msg()), list(Validator.msg()))
			:: {%AdversarialSimulation{}, list(Validator.msg()), list(Validator.msg())}
	def slotHonestMsgs(config, t, validatorIds, msgsInAll, msgsOutPart1, msgsOutPart2) do
		case validatorIds do
			[] -> {config, msgsOutPart1, msgsOutPart2}
			[validatorId | tail] ->
				msgsIn = Map.get(msgsInAll, validatorId, [])

				{config, msgsOutPart1, msgsOutPart2} =
					if Utilities.checkMembership(validatorId, config.validatorsAwake) do
						{config, msgsOutPart1, msgsOutPart2} =
							if Utilities.checkMembership(validatorId, config.validatorsPart1) do
								{validator, msgsOutPart1} =
									HonestValidator.slot(at(config.validators, validatorId), t,
										msgsOutPart1, getMissedMessages(config, validatorId) ++ msgsIn,
										config)

								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							else
								{validator, msgsOutPart2} =
									HonestValidator.slot(at(config.validators, validatorId), t,
										msgsOutPart2, getMissedMessages(config, validatorId) ++ msgsIn,
										config)

								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							end

						config = %{config | msgsMissed: Map.drop(config.msgsMissed, [validatorId])}
						{config, msgsOutPart1, msgsOutPart2}
					else
						newMessagesMissed = getMissedMessages(config, validatorId) ++ msgsIn
						config = %{config | msgsMissed: Map.put(config.msgsMissed,
									validatorId, newMessagesMissed)}
						{config, msgsOutPart1, msgsOutPart2}
					end
				slotHonestMsgs(config, t, tail, msgsInAll, msgsOutPart1, msgsOutPart2)
		end
	end

	@spec getMissedMessages(%AdversarialSimulation{}, non_neg_integer()) :: list(Validator.msg())
	def getMissedMessages(config, validatorId) do
		Map.get(config.msgsMissed, validatorId, [])
	end

	@spec getInflightMessages(%AdversarialSimulation{}, non_neg_integer()) :: %{validator() => list(Validator.msg())}
	def getInflightMessages(config, t) do
		Map.get(config.msgsInflight, t, Map.new(for v <- 0..(config.n-1) do {v, []} end))
	end

	# Put new value in msgsInflight[t]
	@spec modifyInflightMessages(%AdversarialSimulation{}, non_neg_integer(),
		validator()) :: %AdversarialSimulation{}
	def modifyInflightMessages(config, t, value) do
		%{config | msgsInflight:  Map.put(config.msgsInflight, t, value)}
	end

	# Append newMessages for msgsInflight[t][validator]
	@spec appendInflightMessagesValidator(%AdversarialSimulation{}, non_neg_integer(),
		non_neg_integer(), list(Validator.msg())) :: %AdversarialSimulation{}
	def appendInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = getInflightMessages(config, t)
		validatorMessages = tMessages[validatorId] ++ newMessages

		modifyInflightMessages(config, t, Map.put(tMessages, validatorId, validatorMessages))
	end

	# Prepend newMessages for msgsInflight[t][validator]
	@spec prependInflightMessagesValidator(%AdversarialSimulation{}, non_neg_integer(),
		non_neg_integer(), list(Validator.msg())) :: %AdversarialSimulation{}
	def prependInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = getInflightMessages(config, t)
		validatorMessages = newMessages ++ tMessages[validatorId]

		modifyInflightMessages(config, t, Map.put(tMessages, validatorId, validatorMessages))
	end

	# Append msgs for all validators msgsInflight[t]
	@spec appendInflightMessages(%AdversarialSimulation{}, list(non_neg_integer()),
		non_neg_integer(), list(Validator.msg())) :: %AdversarialSimulation{}
	def appendInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = appendInflightMessagesValidator(config, t, validatorId, msgs)
				appendInflightMessages(config, tail, t, msgs)
		end
	end

	# Prepend msgs for all validators msgsInflight[t]
	@spec prependInflightMessages(%AdversarialSimulation{}, list(non_neg_integer()),
		non_neg_integer(), list(Validator.msg())) :: %AdversarialSimulation{}
	def prependInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = prependInflightMessagesValidator(config, t, validatorId, msgs)
				prependInflightMessages(config, tail, t, msgs)
		end
	end

	# Computes adversarial validator actions for this slot.
	@spec slotAdversarialMessages(%AdversarialSimulation{}, list(non_neg_integer()),
		non_neg_integer(), list(Validator.msg()), list(Validator.msg()),
		list(Validator.msg()), list(Validator.msg()))
			:: {%AdversarialSimulation{}, list(Validator.msg()), list(Validator.msg())}
	def slotAdversarialMessages(config, validatorIds, t, msgsOutPrivateAdversarial,
		msgsOutRushHonest, msgsHonest, msgsInAll) do
			case validatorIds do
				[] -> {config, msgsOutPrivateAdversarial, msgsOutRushHonest}
				[validatorId | tail] ->
					msgsIn = Map.get(msgsInAll, validatorId, [])

					{validator, msgsOutPrivateAdversarial, msgsOutRushHonest} =
						AdversarialValidator.slot(at(config.validators, validatorId),
							config.n, t, msgsOutPrivateAdversarial, msgsOutRushHonest, msgsIn,
							msgsHonest, (config.lambda/config.n)/config.second)

					config = replaceValidator(config, validatorId, validator)
					slotAdversarialMessages(config, tail, t, msgsOutPrivateAdversarial,
						msgsOutRushHonest, msgsHonest, msgsInAll)
			end
	end

	def log_ledger_lengths(config, t) do
		validatorsAwakePart1 = MapSet.intersection(MapSet.new(config.validatorsAwake), MapSet.new(config.validatorsPart1))
		validatorsAwakePart2 = MapSet.intersection(MapSet.new(config.validatorsAwake), MapSet.new(config.validatorsPart2))

		l_Lp_1 = Enum.min(validatorsAwakePart1 |> Enum.map(fn x -> length(HonestValidator.lp(at(config.validators, x), config.n))-1 end))
		l_Lp_2 = Enum.min(validatorsAwakePart2 |> Enum.map(fn x -> length(HonestValidator.lp(at(config.validators, x), config.n))-1 end))
		l_Lda_1 = Enum.min(validatorsAwakePart1 |> Enum.map(fn x -> length(HonestValidator.lda(at(config.validators, x), config.n, config.k))-1 end))
		l_Lda_2 = Enum.min(validatorsAwakePart2 |> Enum.map(fn x -> length(HonestValidator.lda(at(config.validators, x), config.n, config.k))-1 end))

		l_Lp = Enum.min([l_Lp_1, l_Lp_2])
		l_Lda = Enum.min([l_Lda_1, l_Lda_2])

		l_Lda_adv = Enum.min(config.validatorsAdversarial |> Enum.map(fn x -> length(AdversarialValidator.lda(at(config.validators, x), config.k))-1 end))

		IO.puts(inspect([t/config.second, l_Lp, l_Lp_1, l_Lp_2, l_Lda, l_Lda_1, l_Lda_2, length(config.validatorsAwake),
			length(config.validatorsAsleep), l_Lda_adv]))
	end

	@spec runSimulation(%AdversarialSimulation{}, non_neg_integer()) :: %AdversarialSimulation{}
	def runSimulation(config, t) do
		cond do

			t == config.tEnd+1 -> config
			true ->

				# config = daTick(config)

				# config =
				# 	if rem(t, 15*config.second) == 0 do
				# 		case config.livenessPhaseStart do
				# 			nil ->
				# 				if length(config.validatorsAwake) >= 67 do
				# 					%{config | livenessPhaseStart: t}
				# 				else
				# 					config
				# 				end
				# 			_ ->
				# 				if length(config.validatorsAwake) < 67 or t == config.tEnd do
				# 					config = pushLivenessPhase(config,
				# 						{config.livenessPhaseStart, (config.livenessPhaseStart+t)/2, t})
				# 					%{config | livenessPhaseStart: nil}
				# 				else
				# 					config
				# 				end
				# 		end
				# 	else
				# 		config
				# 	end

				{validatorsAwake, validatorsAsleep} =
					if t == config.tPartStart do
						{Enum.slice(config.validatorsHonest, 0, 25), Enum.slice(config.validatorsHonest, 25, config.n-config.f-25)}
					else
						if t == config.tPartStop do
							{config.validatorsHonest, []}
						else
							{config.validatorsAwake, config.validatorsAsleep}
					end

				config = %{config | validatorsAwake: config.validatorsAwake}
				config = %{config | validatorsAsleep: config.validatorsAsleep}

				msgsInAll = getInflightMessages(config, t)

				{config, msgsOutPart1, msgsOutPart2} = slotHonestMsgs(config, t,
					config.validatorsHonest, msgsInAll, [], [])

				{tDeliverInter, tDeliverIntra} =
					if config.tPartStart <= t and t < config.tPartStop do
						{Enum.max([t+config.delta, config.tPartStop]), t+config.delta}
					else
						{t+config.delta, t+config.delta}
					end

				config = modifyInflightMessages(config, tDeliverInter,
					getInflightMessages(config, tDeliverInter))
				config = modifyInflightMessages(config, tDeliverIntra,
					getInflightMessages(config, tDeliverIntra))

				config = appendInflightMessages(config, config.validatorsPart1, tDeliverInter, msgsOutPart2)
				config = appendInflightMessages(config, config.validatorsPart1, tDeliverIntra, msgsOutPart1)

				config = appendInflightMessages(config, config.validatorsPart2, tDeliverInter, msgsOutPart1)
				config = appendInflightMessages(config, config.validatorsPart2, tDeliverIntra, msgsOutPart2)

				msgsHonest = msgsOutPart1 ++ msgsOutPart2

				{config, msgsOutPrivateAdversarial, msgsOutRushHonest} =
					slotAdversarialMessages(config, config.validatorsAdversarial, t, [], [],
						msgsHonest, msgsInAll)

				config = prependInflightMessages(config, config.validatorsHonest,
					t+1, msgsOutRushHonest)

				config = appendInflightMessages(config, config.validatorsAdversarial,
					t+1, msgsOutPrivateAdversarial)
				config = appendInflightMessages(config, config.validatorsAdversarial,
					t+1, msgsOutRushHonest)

				if rem(t, 15*config.second) == 0 do
					log_ledger_lengths(config, t)
				end

				runSimulation(config, t+1)
		end
	end
end
end
