# Class CanvasTileView renders agents, links, and patches in canvas tiles

# ### Class CanvasTileView

class CanvasTileView
  # Class variable for layers parameters.
  # Can be added to by programmer to modify/create layers, **before** starting your own model.
  # Example:
  #
  #     v.z++ for k,v of CanvasView::contextsInit # increase each z value by one
  contextsInit: { # Experimental: image:   {z:15,  ctx:"img"}
    patches:   {z:10, ctx:"2d"}
    drawing:   {z:20, ctx:"2d"}
    links:     {z:30, ctx:"2d"}
    agents:    {z:40, ctx:"2d"}
    spotlight: {z:50, ctx:"2d"}
  },

  constructor: (@model, opts) ->
    # Calculate world size in pixels
    @setWorld opts
    
    # Set drawing controls.  Default to drawing each agentset.
    # Optimization: If any of these is set to false, the associated
    # agentset is drawn only once, remaining static after that.
    @refreshLinks = @refreshAgents = @refreshPatches = true

    # Style the parent div and create rendering contexts 
    (@div=document.getElementById(opts.div)).setAttribute 'style',
        "position:relative; width:#{@world.pxWidth}px; height:#{@world.pxHeight}px"
    
    @map = L.map(opts.div, {
      center: [90, -180],
      zoom: 5,
      crs: L.extend({}, L.CRS.EPSG3857, {
        wrapLat: null, wrapLng: null, infinite: true
      })
    });
    
    @createCtxs()
    u.waitOn((=> @model.modelReady), (=> @createAgentTileLayer()))

  createCtxs: () ->
    # * Create 2D canvas contexts layered on top of each other.
    # * Initialize a patch coord transform for each layer.
    #
    # Note: this transform is permanent .. there isn't the usual ctx.restore().
    # To use the original canvas 2D transform temporarily:
    #
    #     u.setIdentity ctx
    #       <draw in native coord system>
    #     ctx.restore() # restore patch coord system
    @contexts = {}
    # for own k,v of @contextsInit
    #   @contexts[k] = @createTileLayer()

    # # One of the layers is used for drawing only, not an agentset:
    # @drawing = @contexts.drawing
    # @drawing.clear = => u.clearCtx @drawing
    # # Setup spotlight layer, also not an agentset:
    # @contexts.spotlight.globalCompositeOperation = "xor"
    return @contexts

  createAgentTileLayer: () ->
    tileLayer = @tileLayer = new L.TileLayer.Canvas({
      continuousWorld: true
    })

    tileLayer.drawTile = (canvas, tilePoint, zoom) =>
      renderTile = @getDrawTileClosure(canvas, tilePoint, zoom)
      
      @model.on('draw', renderTile)
      
      @map.on('zoomstart', () =>
        @model.off('draw')
      )

      @map.on('layerremove', (e) =>
        if (e.layer is @tileLayer)
          @model.off('draw')
      )

    tileLayer.addTo(@map)
    return tileLayer

  getDrawTileClosure: (canvas, tilePoint, zoom) ->

    @zoom = zoom
    @zoomScale = zoomScale = Math.pow(2, zoom)
    
    ctx = canvas.getContext('2d')
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    # world coordinates of tile corners
    tileTopLeft = [canvas.width * tilePoint.x, canvas.height * tilePoint.y]
    tileBottomRight = [tileTopLeft[0] + canvas.width, tileTopLeft[1] + canvas.height]

    # patch float coordinates of tile corners
    tileTopLeftPatchCoord = @pixelCoordToPatchCoord(tileTopLeft[0], tileTopLeft[1], zoom)
    tileBottomRightPatchCoord = @pixelCoordToPatchCoord(tileBottomRight[0], tileBottomRight[1], zoom)

    # integer coordinates of patches beneath tile corners
    leftPatchX = Math.floor(tileTopLeftPatchCoord[0])
    rightPatchX = Math.ceil(tileBottomRightPatchCoord[0])
    bottomPatchY = Math.floor(tileBottomRightPatchCoord[1])
    topPatchY = Math.ceil(tileTopLeftPatchCoord[1])

    if @debugging then @drawCanvasTile(canvas, tilePoint)

    return () =>
      for x in [leftPatchX..rightPatchX]
        for y in [bottomPatchY..topPatchY]
          curPatch = @model.patches.patch(x, y)
          # @renderPatch(ctx, curPatch, tileTopLeft)

          if @debugging then @renderPatchBorder(ctx, curPatch, tileTopLeft)

          for agent in curPatch.agentsHere()
            @renderAgent(ctx, agent, tileTopLeft)
            
  renderAgent: (ctx, agent, tileTopLeft) ->
    shape = ABM.shapes[agent.shape]
    drawPos = @patchCoordToPixelCoord(agent.x, agent.y, @zoom)
    scaledSize = agent.size * @zoomScale
    # For some reason rotation is reversed compared to the normal canvas view,
    # so we use -heading instead of heading. Maybe because we don't set the
    # transform to flip the y coordinate?
    ABM.shapes.draw(ctx, shape, drawPos[0] - tileTopLeft[0], drawPos[1] - tileTopLeft[1], scaledSize, -agent.heading, agent.color)

  renderPatch: (ctx, patch, tileTopLeft) ->
    patchSize = @world.size # without zoom, how many pixels in a patch
    zoomedPatchSize = @zoomScale * patchSize # at this zoom, how many pixels in a patch

    patchCenter = @patchCoordToPixelCoord(patch.x, patch.y, @zoom)
    patchTop = patchCenter[1] + zoomedPatchSize/2
    patchLeft = patchCenter[0] - zoomedPatchSize/2
    
    startX = patchLeft - tileTopLeft.x
    startY = patchTop - tileTopLeft.y

    ctx.beginPath()
    ctx.moveTo(startX, startY)
    ctx.lineTo(startX + zoomedPatchSize, startY)
    ctx.lineTo(startX + zoomedPatchSize, startY - zoomedPatchSize)
    ctx.lineTo(startX, startY - zoomedPatchSize)
    ctx.closePath()
    ctx.fillStyle = u.colorStr(patch.color)
    ctx.fill()

  pixelCoordToPatchCoord: (x, y, zoom) ->
    zoomScale = Math.pow(2, zoom)
    unzoomedX = x / zoomScale
    unzoomedY = y / zoomScale
    return @model.patches.pixelXYtoPatchXY(unzoomedX, unzoomedY)

  patchCoordToPixelCoord: (x, y, zoom) ->
    zoomScale = Math.pow(2, zoom)
    pixelCoord = @model.patches.patchXYtoPixelXY(x, y)
    zoomedX = pixelCoord[0] * zoomScale
    zoomedY = pixelCoord[1] * zoomScale
    return [zoomedX, zoomedY]

  # clear/resize canvas transforms
  reset: () ->
    # (v.restore(); @setCtxTransform v) for k,v of @contexts when v.canvas?

  # Call the agentset draw methods if either the first draw call or
  # their "refresh" flags are set.  The latter are simple optimizations
  # to avoid redrawing the same static scene. 
  draw: (force) ->
    # @model.patches.draw @contexts.patches  if force or @refreshPatches or @anim.draws is 1
    # @model.links.draw   @contexts.links    if force or @refreshLinks   or @anim.draws is 1
    # @model.agents.draw  @contexts.agents   if force or @refreshAgents  or @anim.draws is 1
    # @drawSpotlight @model.spotlightAgent, @contexts.spotlight  if @model.spotlightAgent?

  # Initialize/reset world parameters.
  setWorld: (opts) ->
    w = defaults = { size: 13, minX: -16, maxX: 16, minY: -16, maxY: 16, isTorus: false, hasNeighbors: true, isHeadless: false }
    for own k,v of opts
      w[k] = v
    {size, minX, maxX, minY, maxY, isTorus, hasNeighbors, isHeadless} = w
    numX = maxX-minX+1; numY = maxY-minY+1; pxWidth = numX*size; pxHeight = numY*size
    minXcor=minX-.5; maxXcor=maxX+.5; minYcor=minY-.5; maxYcor=maxY+.5
    @world = {size,minX,maxX,minY,maxY,minXcor,maxXcor,minYcor,maxYcor,
      numX,numY,pxWidth,pxHeight,isTorus,hasNeighbors,isHeadless}

  ## debugging drawing utilities

  debug: (@debugging = true) ->

  drawCanvasTile: (canvas, tilePoint) ->
    ctx = canvas.getContext('2d')
    ctx.strokeStyle = 'rgb(0,0,0)'
    ctx.fillStyle = 'rgb(0,0,0)'
    ctx.strokeRect(0, 0, canvas.width, canvas.height)
    ctx.textAlign = 'center'
    ctx.fillText("tile (#{tilePoint.x}, #{tilePoint.y})", canvas.width/2, canvas.height/2)

  renderPatchBorder: (ctx, patch, tileTopLeft) ->
    patchSize = @world.size # without zoom, how many pixels in a patch
    zoomedPatchSize = @zoomScale * patchSize # at this zoom, how many pixels in a patch

    patchCenter = @patchCoordToPixelCoord(patch.x, patch.y, @zoom)
    patchTop = patchCenter[1] + zoomedPatchSize/2
    patchLeft = patchCenter[0] - zoomedPatchSize/2
    
    startX = patchLeft - tileTopLeft.x
    startY = patchTop - tileTopLeft.y

    ctx.beginPath()
    ctx.moveTo(startX, startY)
    ctx.lineTo(startX + zoomedPatchSize, startY)
    ctx.lineTo(startX + zoomedPatchSize, startY - zoomedPatchSize)
    ctx.lineTo(startX, startY - zoomedPatchSize)
    ctx.closePath()
    ctx.strokeStyle = 'rgb(0,0,255)'
    ctx.stroke()
