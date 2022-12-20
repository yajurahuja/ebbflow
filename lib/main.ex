defmodule Main do

	use Application

	def start(_type, _args) do
		config = AdversarialSimulation.new(100, 25)

		_ = AdversarialSimulation.runSimulation(config, 0)
	end
	
end