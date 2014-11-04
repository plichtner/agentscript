# A NetLogo-like mouse handler.
# See: [addEventListener](http://goo.gl/dq0nN)
class ABM.Mouse
  # Create and start mouse obj, args: a model, and a callback method.
  constructor: (@model, @callback) ->
    @lastX = Infinity; @lastY = Infinity
    @div = @model.div
    @lastAgents = []
    @draggingAgents = []
    @start()
  # Start/stop the mouseListeners.  Note that NetLogo's model is to have
  # mouse move events always on, rather than starting/stopping them
  # on mouse down/up.  We may want do make that optional, using the
  # more standard down/up enabling move events.
  start: -> # Note: multiple calls safe
    @div.addEventListener("mousedown", @handleMouseDown, false)
    document.body.addEventListener("mouseup", @handleMouseUp, false)
    @div.addEventListener("mousemove", @handleMouseMove, false)
    @model.on('step', @handleStep)
    @lastX=@lastY=@x=@y=@pixX=@pixY=NaN; @moved=@down=false
  stop: -> # Note: multiple calls safe
    @div.removeEventListener("mousedown", @handleMouseDown, false)
    document.body.removeEventListener("mouseup", @handleMouseUp, false)
    @div.removeEventListener("mousemove", @handleMouseMove, false)
    @model.off('step', @handleStep)
    @lastX=@lastY=@x=@y=@pixX=@pixY=NaN; @moved=@down=false
  # Handlers for eventListeners
  handleMouseDown: (e) =>
    @down = true
    @moved = false
    @handleMouseEvent(e)
  handleMouseUp: (e) =>
    @down = false
    @moved = false
    @handleMouseEvent(e)
  handleMouseMove: (e) =>
    @setXY(e)
    @moved = true
    @handleMouseEvent(e)
  handleStep: () =>
    @delegateMouseOverAndOutEvents(@x, @y) if not isNaN(@x)
    @deligateAgentDragEvents(@x, @y) if not isNaN(@x)
  handleMouseEvent: (e) =>
    eventTypes = @computeEventTypes()
    @delegateEventsToAllAgents(eventTypes, e)
    @callback(e) if @callback?

  setXY: (e) ->
    @lastX = @x; @lastY = @y
    @pixX = e.offsetX; @pixY = e.offsetY
    [@x, @y] = @model.patches.pixelXYtoPatchXY(@pixX,@pixY)

  computeEventTypes: () =>
    eventTypes = []

    if @down and not @moved
      console.log('mousedown')
      eventTypes.push 'mousedown'

    if not @down and not @moved
      console.log('mouseup')
      eventTypes.push 'mouseup'

    if @down and @moved
      if not @dragging
        eventTypes.push 'dragstart'
      @dragging = true

    if not @down and @dragging
      @dragging = false
      console.log('dragend')
      eventTypes.push 'dragend'

    if @moved
      eventTypes.push 'mousemove'
      console.log('mousemove')

    return eventTypes

  delegateEventsToAllAgents: (types, e) ->
    @delegateEventsToAgentsAtPoint(types, @x, @y, e)
    @delegateEventsToLinksAtPoint(types, @x, @y, e)
    @delegateEventsToPatchAtPoint(types, @x, @y, e)
    @delegateMouseOverAndOutEvents(@x, @y, e)

  delegateMouseOverAndOutEvents: (x, y, e) =>
    agentsHere = {}
    agents = []
    curPatch = @model.patches.patch(x, y)
    
    agents = u.clone(@model.links)
    for patch in curPatch.n.concat(curPatch)
      agents = agents.concat(patch.agentsHere())

    # mouseover
    for agent in agents
      if agent.hitTest(x, y)
        agentsHere[agent.breed.name] ?= {}
        agentsHere[agent.breed.name][agent.id] = agent
        if (not @lastAgents[agent.breed.name] or agent.id not of @lastAgents[agent.breed.name])
          mouseEvent = {target: agent, patchX: x, patchY: y, originalEvent: e}
          agent.emit('mouseover', mouseEvent)

    # mouseout
    for breedname of @lastAgents
      for agentId of @lastAgents[breedname]
        if (not agentsHere[breedname] or agentId not of agentsHere[breedname])
          agent = @lastAgents[breedname][agentId]
          mouseEvent = {target: agent, patchX: x, patchY: y, originalEvent: e}
          agent.emit('mouseout', mouseEvent)

    @lastAgents = agentsHere

  deligateAgentDragEvents: (x, y) ->
    for agent in @draggingAgents
      mouseEvent = {target: agent, patchX: x, patchY: y}
      agent.emit('drag', mouseEvent)

  delegateEventsToPatchAtPoint: (eventTypes, x, y, e) ->
    curPatch = @model.patches.patch(x, y)
    mouseEvent = {target: curPatch, patchX:  x, patchY: y, originalEvent: e}
    @emitAgentEvent(type, curPatch, mouseEvent) for type in eventTypes

  delegateEventsToAgentsAtPoint: (eventTypes, x, y, e) ->
    curPatch = @model.patches.patch(x, y)

    # iterate through all agents in this patch and its neighbors
    for patch in curPatch.n.concat(curPatch)
      for agent in patch.agentsHere()
        if agent.hitTest(x, y)
          mouseEvent = {target: agent, patchX:  x, patchY: y, originalEvent: e}
          @emitAgentEvent(type, agent, mouseEvent) for type in eventTypes

  delegateEventsToLinksAtPoint: (eventTypes, x, y, e) ->
    for link in @model.links
      if link.hitTest(x, y)
        mouseEvent = {target: link, patchX:  x, patchY: y, originalEvent: e}
        @emitAgentEvent(type, link, mouseEvent) for type in eventTypes

  emitAgentEvent: (eventType, agent, mouseEvent) ->
    if eventType == 'dragstart'
      @draggingAgents.push(agent)
    if eventType == 'dragend'
      @draggingAgents = []
    agent.emit(eventType, mouseEvent) 