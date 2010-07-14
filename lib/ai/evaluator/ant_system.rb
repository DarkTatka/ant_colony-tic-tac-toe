module AI
  module Evaluator
    module AntSystem
      require 'pstore'

      class AntSystem
        attr_accessor :state, :ant_count, :ant, :alpha, :target
        def initialize(filename, ant_count)
          load_state filename
          @ant_count = ant_count
          @alpha = 1
          @coef = 1
          @evap_rate = 0.5
        end

        def load_state(filename)
          @state = PStore.new(filename)
        end

        def reset
          initialize_trails
          initialize_ants
        end

        def initialize_trails
          @state.transaction do
            @state[:trails] = {}
            @state[:trails].default = 1.0
          end
        end

        def learn(ant)
          add_ant ant
          ants = nil
          @state.transaction do
            ants = @state[:ants].size
          end
          if ants >= ant_count then
            puts 'meh'
            evaporate_trails
            update_pheromones
            initialize_ants
          end
        end

        def add_ant(ant)
          @state.transaction do
            @state[:ants] << ant
          end
        end

        def evaporate_trails
          @state.transaction do
            @state[:trails].dup.each do |key, value|
              @state[:trails][key] = value*(1 - @evap_rate)
            end
            @state[:trails].default = @state[:trails].default * (1 - @evap_rate)
          end
        end

        def update_pheromones
          ants = nil
          @state.transaction do
            ants = @state[:ants]
          end
          ants.map{|ant| [ant, compute_pheromone(ant)]}.each{|pair| update_pair(pair)}
        end

        def compute_pheromone(ant)
          1.0 / ant.size**@coef
        end

        # pair is in format [ant_trail, pheromone_value]
        def update_pair(pair)
          local_ant = pair[0]
          ph_value = pair[1]
          @state.transaction do
            until local_ant.size == 1
              @state[:trails][[local_ant[0], local_ant[1]]] += ph_value
              local_ant.shift
            end
          end
        end

        def initialize_ants
          @state.transaction do
            @state[:ants] = []
          end
        end

        def step(ant)
          #we are going forward
          #pick next step
          neigh = neighbours(ant.last, ant)
          path_probabilities = neigh.map{|target| p(ant.last, target, ant)}
          picked_number = rand
          next_step = catch(:done) do
            path_probabilities.each_with_index do |prob, index|
	            picked_number -= prob
             throw(:done, neigh[index]) if picked_number <= 0.0
            end
          end
          return next_step
        end

        # return probability for path i -> j and ant k
        def p(i, j, k)
          n = neighbours(i, k)
          if n.include?(j) then
            @state.transaction do
              @state[:trails][[i, j]]**@alpha / n.inject(0){|sum, n| sum + @state[:trails][[i, n]]**@alpha}
            end
          else
            return 0.0
          end
        end

        # return neighbours of node i for ant k
        def neighbours(i, k)
          rules = TicTacToe.new(i)
          return rules.moves.map{|move| rules.apply(move).hash}
        end
      end
    end
  end
end

