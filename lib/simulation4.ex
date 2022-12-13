defmodule OverviewSimulation do
  	
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

		validatorsPart1: nil,
		validatorsPart2: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil,

		genesisDA: nil,
		genesisP: nil

	)

	@spec new() :: %OverviewSimulation{}
	def new(n, f) do 
		validators = 
			for id <- 1..n do 
				if id<= (n-f) do 
					HonestValidator.new(id) 
				else 
					AdversarialValidator.new(id) 
				end 
			end
		genesisDA = DABlock.genesis()
		%OverviewSimulation{
			rngDa: MersenneTwister.init(2121+1),

			validators: validators,
			
			validatorsHonest: for id <- 1..(n-f) do id end,
			validatorsAdversarial: for id <- (n-f+1)..n do id end,
			
			validatorsAwake: for id <- 1..n do id end,
			validatorsAsleep: [],
			
			validatorsPart1: for id <- 1..(n-f)/2 do id end,
			validatorsPart2: for id <- ((n-f)/2+1)..(n-f) do id end,

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators do {v.id, []} end),

			livenessPhase: [],

			genesisDA: genesisDA,
			genesisP: PBlock.genesis(genesisDA)

		}
	end

	@spec shuffleAwake(%OverviewSimulation{}) :: %OverviewSimulation{}
	def shuffleAwake(config) do
		%{config | validatorsAwake: shuffle(config.validatorsAwake)}
	end

	@spec shuffleAsleep(%OverviewSimulation{}) :: %OverviewSimulation{}
	def shuffleAsleep(config) do
		%{config | validatorsAsleep: shuffle(config.validatorsAsleep)}
	end

	@spec popAwake(%OverviewSimulation{}) :: %OverviewSimulation{}
	def popAwake(config) do
		%{config | validatorsAwake: List.tail(config.validatorsAwake)}
	end

	@spec popAsleep(%OverviewSimulation{}) :: %OverviewSimulation{}
	def popAsleep(config) do
		%{config | validatorsAsleep: List.tail(config.validatorsAsleep)}
	end

	@spec pushAwake(%OverviewSimulation{}, non_neg_integer()) 
		:: %OverviewSimulation{}
	def pushAwake(config, validatorId) do
		%{config | validatorsAwake: config.validatorsAwake ++ [validatorId]}
	end
	@spec pushAsleep(%OverviewSimulation{}, non_neg_integer()) 
		:: %OverviewSimulation{}
	def pushAsleep(config, validatorId) do
		%{config | validatorsAsleep: config.validatorsAsleep ++ [validatorId]}
	end

	@spec pushAsleep(%OverviewSimulation{}, 
		{non_neg_integer(), non_neg_integer(), non_neg_integer()}) 
			:: %OverviewSimulation{}
	def pushLivenessPhase(config, phase) do
		%{config | livenessPhase: config.livenessPhase ++ [phase]}
	end

	# Puts an honest validator to sleep, or wakes it up, or does nothing.
	@spec daTick(%OverviewSimulation{}) :: %OverviewSimulation{}
	def daTick(config) do
		:rand.seed(config.rngDa)
		dir = 
			cond do
				List.length(config.validatorsAwake) == 60 -> random([:toawake, :nothing])
				List.length(config.validatorsAwake) == (config.n-config.f) -> random([:nothing, :toasleep])
				true -> random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake -> 
				config = shuffleAsleep(config)
				popAsleep(pushAwake(config, List.head(config.validatorsAsleep)))
			dir == :toasleep -> 
				config = shuffleAwake(config)
				popAwake(pushAsleep(config, List.head(config.validatorsAwake)))
			true -> config
		end
	end

	# Replaces validator object having given id.
	@spec replaceValidator(%OverviewSimulation{}, non_neg_integer(), validator()) 
		:: %OverviewSimulation{}
	def replaceValidator(config, validatorId, newValidator) do
		%{config | validators: 
			map(config.validators, 
				fn x -> 
					if x.id == validatorId do 
						newValidator 
					else 
						x 
					end)}
	end

	# Computes honest awake validator actions for this slot.
	# Collects messages missed by asleep validators.
	# Set validatorIds to config.validatorsHonest. 
	# msgsOutPart1 aggregagates msgs output by validatorsPart1. 
	#		On initial call, it should be empty. Same for msgsOutPart2.
	@spec slotHonestMsgs(%OverviewSimulation{}, list(non_neg_integer()), 
		list(Validator.msg()), list(Validator.msg())) 
			:: {%OverviewSimulation{}, list(Validator.msg()), list(Validator.msg())}
	def slotHonestMsgs(config, validatorIds, msgsOutPart1, msgsOutPart2) do
		case validatorIds do
			[] -> {config, msgsOutPart1, msgsOutPart2}
			[validatorId | tail] ->
				msgsIn = Map.get(config.msgsInAll, validatorId, [])

				{config, msgsOutPart1, msgsOutPart2} = 
					if Utilities.checkMembership(config.validatorsAwake, validatorId) do
						{config, msgsOutPart1, msgsOutPart2} = 
							if Utilities.checkMembership(config.validatorsPart1, validatorId) do
								{validator, msgsOutPart1} = 
									HonestValidator.slot(at(config.validators, validatorId), t, 
										msgsOutPart1, config.msgsMissed[validatorId] ++ msgsIn)
								
								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							else
								{validator, msgsOutPart2} = 
									HonestValidator.slot(at(config.validators, validatorId), t, 
										msgsOutPart2, config.msgsMissed[validatorId] ++ msgsIn)
								
								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							end
						
						config = %{config | msgsMissed: Map.drop(config.msgsMissed, validatorId)}
						{config, msgsOutPart1, msgsOutPart2}
					else
						config = %{config | msgsMissed: Map.replace(config.msgsMissed, 
									validatorId, config.msgsMissed[validatorId] ++ msgsIn)}
						{config, msgsOutPart1, msgsOutPart2}
					end
				slotHonestMsgs(config, tail, msgsOutPart1, msgsOutPart2)
		end
	end

	# Put new value in msgsInflight[t]
	@spec modifyInflightMessages(%OverviewSimulation{}, non_neg_integer(), 
		validator()) :: %OverviewSimulation{}
	def modifyInflightMessages(config, t, value) do
		%{config | msgsInflight: Map.put(config.msgsInflight, t, value) }
	end

	# Append newMessages for msgsInflight[t][validator]
	@spec appendInflightMessagesValidator(%OverviewSimulation{}, non_neg_integer(), 
		non_neg_integer(), list(Validator.msg())) :: %OverviewSimulation{}
	def appendInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = config.msgsInflight[t]
		validatorMessages = tMessages[validatorId] ++ newMessages

		%{config | msgsInflight: modifyInflightMessages(config, t, 
			Map.put(tMessages, validatorId, validatorMessages))}
	end

	# Prepend newMessages for msgsInflight[t][validator]
	@spec prependInflightMessagesValidator(%OverviewSimulation{}, non_neg_integer(),
		non_neg_integer(), list(Validator.msg())) :: %OverviewSimulation{}
	def prependInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = config.msgsInflight[t]
		validatorMessages = newMessages ++ tMessages[validatorId]

		%{config | msgsInflight: modifyInflightMessages(config, t, 
			Map.put(tMessages, validatorId, validatorMessages))}
	end

	# Append msgs for all validators msgsInflight[t]
	@spec appendInflightMessages(%OverviewSimulation{}, list(non_neg_integer()),
		non_neg_integer(), list(Validator.msg())) :: %OverviewSimulation{}
	def appendInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = appendInflightMessagesValidator(config, t, validatorId, msgs)
				appendInflightMessages(config, tail, t, msgs)
		end
	end

	# Prepend msgs for all validators msgsInflight[t]
	@spec prependInflightMessages(%OverviewSimulation{}, list(non_neg_integer()),
		non_neg_integer(), list(Validator.msg())) :: %OverviewSimulation{}
	def prependInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = prependInflightMessagesValidator(config, t, validatorId, msgs)
				prependInflightMessages(config, tail, t, msgs)
		end
	end

	# Computes adversarial validator actions for this slot.
	@spec slotAdversarialMessages(%OverviewSimulation{}, list(non_neg_integer()), 
		non_neg_integer(), list(Validator.msg()), list(Validator.msg()), 
		list(Validator.msg())) 
			:: {%OverviewSimulation{}, list(Validator.msg()), list(Validator.msg())}
	def slotAdversarialMessages(config, validatorIds, t, msgsOutPrivateAdversarial, 
		msgsOutRushHonest, msgsHonest, msgsInAll) do
			case validatorIds do
				[] -> {config, msgsOutPrivateAdversarial, msgsOutRushHonest}
				[validatorId | tail] ->
					msgsIn = Map.get(config.msgsInAll, validatorId, [])
					{validator, msgsOutPrivateAdversarial, msgsOutRushHonest} = 
						AdversarialValidator.slot(at(config.validator, validatorId), 
							config.n, t, msgsOutPrivateAdversarial, msgsOutRushHonest, msgsIn, 
							msgsHonest)
					config = replaceValidator(config, validatorId, validator)
					slotAdversarialMessages(config, tail, t, msgsOutPrivateAdversarial, 
						msgsOutRushHonest, msgsHonest, msgsInAll)
			end
	end

	def log_ledger_lengths(config, t) do
		validatorsAwakePart1 = MapSet.intersect(MapSet.new(config.validatorsAwake), MapSet.new(config.validatorsPart1))
		validatorsAwakePart2 = MapSet.intersect(MapSet.new(config.validatorsAwake), MapSet.new(config.validatorsPart2))
		
		l_Lp_1 = Enum.min(validatorsAwakePart1 |> Enum.map(fn x -> List.length(HonestValidator.lp(x))-1 end))
		l_Lp_2 = Enum.min(validatorsAwakePart2 |> Enum.map(fn x -> List.length(HonestValidator.lp(x))-1 end))
		l_Lda_1 = Enum.min(validatorsAwakePart1 |> Enum.map(fn x -> List.length(HonestValidator.lda(x))-1 end))
		l_Lda_2 = Enum.min(validatorsAwakePart2 |> Enum.map(fn x -> List.length(HonestValidator.lda(x))-1 end))

		l_Lp = Enum.min(l_Lp_1, l_Lp_2)
		l_Lda = Enum.min(l_Lda_1, l_Lda_2)

		l_Lda_adv = Enum.min(validatorsAdversarial |> Enum.map(fn x -> List.length(AdversarialValidator.lda(x))-1 end))

		IO.puts(inspect([t/config.second, l_Lp, l_Lp_1, l_Lp_2, l_Lda, l_Lda_1, l_Lda_2, List.length(config.validatorsAwake), 
			List.length(config.validatorsAsleep), l_Lda_adv]))
	end

	@spec runSimulation(%OverviewSimulation{}, non_neg_integer()) :: %OverviewSimulation{}
	def runSimulation(config, t) do

		cond do

			t == config.tEnd+1 -> config
			true -> 
			
				config = daTick(config)

				config = 
					if rem(t, 15*config.second) == 0 do
						case config.livenessPhaseStart do
							nil -> 
								if List.length(config.validatorsAwake) >= 67 do
									%{config | livenessPhaseStart: t}
								else
									config
								end
							_ -> 
								if List.length(config.validatorsAwake) < 67 or t == config.tEnd do
									config = pushLivenessPhase(config, 
										{config.livenessPhaseStart, (config.livenessPhaseStart+t)/2, t})
									%{config | livenessPhaseStart: nil}
								else
									config
								end
						end
					else
						config
					end

				msgsInAll = Map.get(config.msgsInflight, t, Map.new())

				{config, msgsOutPart1, msgsOutPart2} = slotHonestMsgs(config, 
					config.validatorsAwake, [], [])

				{tDeliverInter, tDeliverIntra} = 
					if config.tPartStop <= t and t < tPartStop do
						{Enum.max(t+config.delta, config.tPartStop), t+config.delta}
					else
						{t+config.delta, t+config.delta}
					end

				config = modifyInflightMessages(config, tDeliverInter, 
					Map.get(config.msgsInflight, tDeliverInter, 
						(Map.new(for v <- 1..config.n do {v.id, []} end))))
				config = modifyInflightMessages(config, tDeliverIntra, 
					Map.get(config.msgsInflight, tDeliverIntra, 
						(Map.new(for v <- 1..config.n do {v.id, []} end))))

				config = appendInflightMessages(config, config.validatorsPart1, tDeliverInter, msgsOutPart2)
				config = appendInflightMessages(config, config.validatorsPart1, tDeliverIntra, msgsOutPart1)

				config = appendInflightMessages(config, config.validatorsPart2, tDeliverInter, msgsOutPart1)
				config = appendInflightMessages(config, config.validatorsPart2, tDeliverIntra, msgsOutPart2)

				msgsHonest = msgsOutPart1 ++ msgsOutPart2

				{config, msgsOutPrivateAdversarial, msgsOutRushHonest} = 
					slotAdversarialMessages(config, config.validatorsAdversarial, t, [], [], 
						msgsHonest, msgsInAll)

				config = %{config | msgsInflight: Map.get(config.msgsInflight, t+1, 
					Map.new(for v <- config.validators do {v.id, []} end))}

				config = prependInflightMessages(msgsInflight, config.validatorsHonest, 
					t+1, msgsOutRushHonest)

				config = appendInflightMessages(msgsInflight, config.validatorsAdversarial, 
					t+1, msgsOutPrivateAdversarial)
				config = appendInflightMessages(msgsInflight, config.validatorsAdversarial, 
					t+1, msgsOutRushHonest)

				if rem(t, 15*config.second) == 0 do
					log_ledger_lengths(config, t)
				end				

				runSimulation(config, t+1)
		end

	end


end



