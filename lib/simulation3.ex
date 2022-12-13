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

		validatorsAwake: nil,
		validatorsAsleep: nil,

		part1Validators: nil,
		part2Validators: nil,

		msgsInflight: nil,
		msgsMissed: nil,

		livenessPhase: nil,
		livenessPhaseStart: nil

	]

	@spec newConfiguration(non_negative_integer(), non_negative_integer()) :: %DPSimulation{}
	def newConfiguration(n, f) do
		validators = for id <- 1..n, do (if id <= (n-f) do %HonestValidator(id) else %AdversarialValidator(id) end)
		%%DPSimulation{
			validators: validators,

			validatorsHonest: Enum.slice(validators, 0, n-f),
			validatorsAdversarial: Enum.slice(validators, n-f, f),

			validatorsAwake: validators,
			validatorsAsleep: [],

			validatorsPart1: Enum.slice(validators, 0, (n-f)*4/5),
			validatorsPart2: Enum.slice(validators, (n-f)*4/5, (n-f)/5),

			msgsInflight: Map.new(),
			msgsMissed: Map.new(for v <- validators, {v, []}),

			livenessPhase: []
		}
	end

	def shuffleAwake(config) do
		%{config | validatorsAwake: enum.shuffle(config.validatorsAwake)}
	end

	def shuffleAsleep(config) do
		%{config | validatorsAsleep: enum.shuffle(config.validatorsAsleep)}
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
			dir == :toawake -> popAsleep(pushAwake(config, head(config.validatorsAsleep)))
			dir == :toasleep -> popAwake(pushAsleep(config, head(config.validatorsAwake)))
			_ -> config
		end
	end


  def missed_messages(config, validators) do
    if length(validators) == 0 do
      config
    else
      v = hd(validators)
      if Utilities.checkMembership(v, config.validatorsAwake) do
        {_, _, msgs_out} =
        cond do

        end
      end
    end
  end


	def runSimulation(config, t) do
		config = daTick(config)

    #prepare message queues

    config = %{config | msgsInflight: Map.put(config.msgsInflight, t + config.delta, [])}
    msgs_out = Map.get(config.msgsInflight, t + config.delta, [])
    msgs_in = Map.get(config.msgsInflight, t, [])

    #TODO: compute awake validator actions for this slot & collect messages missed by asleep validators
    {l_LP, l_LDA} =
    if rem(t, 15) == 0 do
      l_LP = Enum.min(Enum.map(validatorsAwake, fn x -> length(HonestValidator.lp(x)) - 1 end))
      l_LDA = Enum.min(Enum.map(validatorsAwake, fn x -> length(HonestValidator.lda(x)) - 1 end))
      #TODO: print the l_LP, l_LDA
      {l_LP, l_LDA}
    else
      {nil, nil}
    end

	end


end
