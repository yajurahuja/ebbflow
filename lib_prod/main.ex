defmodule Main do

	use Application

	def start(_type, _args) do
		config = OverviewSimulation.new()

		_ = OverviewSimulation.runSimulation(config, 0)
	end
	
end