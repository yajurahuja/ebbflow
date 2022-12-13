defmodule OverviewSimulation do
  	
  @type validator() :: %HonestValidator{} | %AdversarialValidator{}

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

		validatorsAwake: nil,
		validatorsAsleep: nil,

		validatorsPart1: nil,
		validatorsPart2: nil,

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
			
			validatorsHonest: for id <- 1..(n-f), do id,
			validatorsAdversarial: for id <- (n-f+1)..n, do id,
			
			validatorsAwake: for id <- 1..n, do id,
			validatorsAsleep: [],
			
			validatorsPart1: for id <- 1..(n-f)/2, do id,
			validatorsPart2: for id <- ((n-f)/2+1)..(n-f), do id,

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators, {v.id, []}),

			livenessPhase: []
		}
	end

	def shuffleAwake(config) do
		%{config | validatorsAwake: shuffle(config.validatorsAwake)}
	end

	def shuffleAsleep(config) do
		%{config | validatorsAsleep: shuffle(config.validatorsAsleep)}
	end

	def popAwake(config) do
		%{config | validatorsAwake: List.tail(config.validatorsAwake)}
	end

	def popAsleep(config) do
		%{config | validatorsAsleep: List.tail(config.validatorsAsleep)}
	end

	def pushAwake(config, val) do
		%{config | validatorsAwake: config.validatorsAwake ++ [val]}
	end

	def pushAsleep(config, val) do
		%{config | validatorsAsleep: config.validatorsAsleep ++ [val]}
	end

	def pushLivenessPhase(config, val) do
		%{config | livenessPhase: config.livenessPhase ++ [val]}
	end

	@spec daTick(%OverviewSimulation{}) :: %OverviewSimulation{}
	def daTick(config) do
		:rand.seed(config.rngDa)
		dir = 
			cond do
				List.length(awake) == 60 -> random([:toawake, :nothing])
				List.length(awake) == (config.n-config.f) -> random([:nothing, :toasleep])
				_ -> random([:toawake, :toasleep])
			end

		cond do
			dir == :toawake -> 
				config = shuffleAsleep(config)
				popAsleep(pushAwake(config, head(config.validatorsAsleep)))
			dir == :toasleep -> 
				config = shuffleAwake(config)
				popAwake(pushAsleep(config, head(config.validatorsAwake)))
			_ -> config
		end
	end

	@spec replaceValidator(%OverviewSimulation{}, non_neg_integer(), validator()) :: %OverviewSimulation{}
	def replaceValidator(config, validatorId, newValidator) do
		%{config | validators: map(config.validators, fn x -> (if x.id == validatorId, do: newValidator, else: x end))}
	end

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
									HonestValidator.slot(at(config.validators, validatorId), t, msgsOutPart1, config.msgsMissed[validatorId] ++ msgsIn)
								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							else
								{validator, msgsOutPart2} = 
									HonestValidator.slot(at(config.validators, validatorId), t, msgsOutPart2, config.msgsMissed[validatorId] ++ msgsIn)
								config = replaceValidator(config, validatorId, validator)
								{config, msgsOutPart1, msgsOutPart2}
							end
						config = %{config | msgsMissed: Map.drop(config.msgsMissed, validatorId)}
						{config, msgsOutPart1, msgsOutPart2}
					else
						config = %{config | msgsMissed: Map.replace(config.msgsMissed, validatorId, config.msgsMissed[validatorId] ++ msgsIn)}
						{config, msgsOutPart1, msgsOutPart2}
					end
				slotHonestMsgs(config, tail, msgsOutPart1, msgsOutPart2)
		end
	end

	def modifyInflightMessages(config, t, val) do
		%{config | msgsInflight: Map.put(config.msgsInflight, t, val) }
	end

	def appendInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = config.msgsInflight[t]
		validatorMessages = tMessages[validatorId] ++ newMessages

		%{config | msgsInflight: Map.put(config.tMessages, t, 
			Map.put(tMessages, validatorId, validatorMessages))}
	end

	def prependInflightMessagesValidator(config, t, validatorId, newMessages) do
		tMessages = config.msgsInflight[t]
		validatorMessages = newMessages ++ tMessages[validatorId]

		%{config | msgsInflight: Map.put(config.tMessages, t, 
			Map.put(tMessages, validatorId, validatorMessages))}
	end

	def appendInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = appendInflightMessagesValidator(config, t, validatorId, msgs)
				appendInflightMessages(config, tail, t, msgs)
		end
	end

	def prependInflightMessages(config, validatorIds, t, msgs) do
		case validatorIds do
			[] -> config
			[validatorId | tail] ->
				config = prependInflightMessagesValidator(config, t, validatorId, msgs)
				prependInflightMessages(config, tail, t, msgs)
		end
	end

	def slotAdversarialMessages(config, validatorIds, t, msgsOutPrivateAdversarial, msgsOutRushHonest, msgsHonest, msgsInAll) do
		case validatorIds do
			[] -> {config, msgsOutPrivateAdversarial, msgsOutRushHonest}
			[validatorId | tail] ->
				msgsIn = Map.get(config.msgsInAll, validatorId, [])
				{validator, msgsOutPrivateAdversarial, msgsOutRushHonest} = 
					AdversarialValidator.slot(at(config.validator, validatorId), 
						config.n, t, msgsOutPrivateAdversarial, msgsOutRushHonest, msgsIn, msgsHonest)
				config = replaceValidator(config, validatorId, validator)
				slotAdversarialMessages(config, tail, t, msgsOutPrivateAdversarial, msgsOutRushHonest, msgsHonest, msgsInAll)
	end

	def runSimulation(config, t) do

		cond do

			t == config.tEnd -> config
			_ -> 
			
				config = daTick(config)

				config = 
					if rem(t, 15*config.second) == 0 do
						case config.livenessPhaseStart do
							nil -> 
								if List.length(config.validatorsAwake) >= 67 do
									%{config | livenessPhaseStart = t}
								else
									config
								end
							_ -> 
								if List.length(config.validatorsAwake) < 67 or t == config.tEnd do
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

				{config, msgsOutPart1, msgsOutPart2} = slotHonestMsgs(config, config.validatorsAwake, [], [])

				{tDeliverInter, tDeliverIntra} = 
					if config.tPartStop <= t < tPartStop do
						{Enum.max(t+config.delta, config.tPartStop), t+config.delta}
					else
						{t+config.delta, t+config.delta}
					end

				config = modifyInflightMessages(config, tDeliverInter, 
					Map.get(config.msgsInflight, tDeliverInter, (Map.new(for v <- 1..config.n, {v.id, []})))
				config = modifyInflightMessages(config, tDeliverIntra, 
					Map.get(config.msgsInflight, tDeliverIntra, (Map.new(for v <- 1..config.n, {v.id, []})))

				config = appendInflightMessages(config, config.validatorsPart1, tDeliverInter, msgsOutPart2)
				config = appendInflightMessages(config, config.validatorsPart1, tDeliverIntra, msgsOutPart1)

				config = appendInflightMessages(config, config.validatorsPart2, tDeliverInter, msgsOutPart1)
				config = appendInflightMessages(config, config.validatorsPart2, tDeliverIntra, msgsOutPart2)

				msgsHonest = msgsOutPart1 ++ msgsOutPart2

				{config, msgsOutPrivateAdversarial, msgsOutRushHonest} = 
					slotAdversarialMessages(config, config.validatorsAdversarial, t, [], [], msgsHonest, msgsInAll)

				config = %{config | msgsInflight: Map.get(config.msgsInflight, t+1, Map.new(for v <- config.validators, {v.id, []}))}

				config = prependInflightMessages(msgsInflight, config.validatorsHonest, t+1, msgsOutRushHonest)

				config = appendInflightMessages(msgsInflight, config.validatorsAdversarial, t+1, msgsOutPrivateAdversarial)
				config = appendInflightMessages(msgsInflight, config.validatorsAdversarial, t+1, msgsOutRushHonest)

				runSimulation(config, t+1)
		end

	end


end



