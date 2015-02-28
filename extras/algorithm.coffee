# algorithm.coffee is a collection of algorithms useful in certain agent-based modeling contexts

# A generalized, but complex, flood fill, designed to work on any
# agentset type. To see a simpler version, look at the gridpath model.
#
# Floodfill arguments:
#
# * startingSet: initial array of agents, often a single agent: [a]
# * fCandidate(a, nextFront) -> true if a is elegible to be added to the set
# * fJoin(a, prevFront) -> adds a to the agentset, usually by setting a variable
# * fNeighbors(a) -> returns the neighbors of this agent (i.e. the agents to which this flood will spread)

class ABM.FloodFill
  constructor: (startingSet, @fCandidate, @fJoin, @fNeighbors) ->
    @nextStep = () => @floodFillOnce()
    @nextFront = startingSet
    @prevFront = []

  floodFillOnce: () =>
    @fJoin p, @prevFront for p in @nextFront
    asetNext = []
    for p in @nextFront
      for n in @fNeighbors(p) when @fCandidate n, @nextFront
        asetNext.push n if asetNext.indexOf(n) < 0
    
    @prevFront = @nextFront
    @nextFront = asetNext

    if @nextFront.length is 0
      @nextStep = null

class ABM.Patches.FloodFill extends ABM.FloodFill
  constructor: (startingSet, @fCandidate, @fJoin, @fNeighbors = ((patch) -> patch.n)) ->
    super(startingSet, @fCandidate, @fJoin, @fNeighbors)

# Link stub
# class ABM.Links.FloodFill extends ABM.FloodFill
#   constructor: (startingSet, @fCandidate, @fJoin, @fNeighbors = ((link) -> patch.n)) ->
#     super(startingSet, @fCandidate, @fJoin, @fNeighbors)