  # ### Color Maps

  # A colormap is an array of colors. Maps are extremely useful:
  #
  # * Performance: Maps are created once, reducing the calls to primitives
  #   whenever a color is changed.
  # * Space Effeciency: They *vastly* reduce the number of colors used.
  # * Data: Their index provides a MatLab/NumPy/NetLogo "color as data" feature.
  #   Ex: "Heat" may be mapped to a gradient from green to red.
  #
  # And you can simply make your own array of legal colors, works fine.
  # And protoMap will even do prototype magic to turn your legal color array
  # into a ColorMap.

ColorMaps  = {

  ColorMap: class ColorMap extends Array
    # colorsArray contains either arrays or legal colors.
    # The type arg specifies the colors in the map.
    #
    # If the special case of colorsArray = a number, an rgb
    # color cube of that dimension will be created.
    #
    # If indexToo then create an object lookup table for direct finding
    # of the color's index in the map. Also, TypedColors have two additional
    # properties: this colormap and the index of the color in the map.
    #
    # If colorsArray contains colors, not an array, and the type differs from
    # the desired type, conversion of the color to the desired color will occur
    # but with a warning message in the console.
    constructor: ( colorsArray, @type="typed", indexToo=(type is "typed") )->
      super(0)
      @index = {} if indexToo
      if typeof colorsArray is "number"
        @cube = colorsArray
        colorsArray = ColorMaps.permuteColors @cube
      type0 = Color.colorType(colorsArray[0])
      if type0 and (type0 isnt type)
        console.log "Primitive color conversion in color map. OK?"
        colorsArray = (Color.colorToArray(c) for c in colorsArray)
      # After this, colorsArray has arrays or colors matching type
      @appendColor color, type for color in colorsArray

    # Append a color to the the map. color is either an array or a valid color.
    # If index object exists keep an index entry pointing to the color index.
    # If type is "typed" add map, index properties to each typedColor.

    # Validate "array" which can be standard or typed array of length 3 or 4
    isValidArray: (array) ->
      (u.isArray(array) or array.buffer) and (array.length in [3..4])

    appendColor: (color) ->
      if @isValidArray color # ToDo: better to use type comparison?
        color = Color.arrayToColor color, @type
      @index[ @indexKey(color) ] = @length if @index
      if @type is "typed"
        color.ix = @length
        color.map = @
      @push color
      color # was null

    # Given a color in the map, return the key it uses in the index object.
    # The value will be the index of the color in the map/array.
    indexKey: (color) -> # make css strings lower case?
      if @type is "typed" then color.pixel else color
    # Use the indexKey to test two map color's equality.
    colorsEqual: (color1, color2) ->
      @indexKey(color1) is @indexKey(color2)

    # Get a random index or color from this map given the
    # input range, defaults to entire map.
    randomIndex: (start=0, stop=@length) -> u.randomInt2 start, stop
    randomColor: (start=0, stop=@length) -> @[ @randomIndex start, stop ]

    # Use Array.sort, augmented by updating index if present
    # and color.ix for typedColors
    sort: (compareFcn) ->
      return if @length is 0
      super compareFcn
      if @index then @index[ @indexKey(color) ] = i for color,i in @
      color.ix = i for color,i in @ if @[0].ix
      null

    # Lookup color in map, returning index or undefined if not found
    lookup: (color) ->
      return @index[ @indexKey(color) ] if @index
      for c,i in @
        return i if @colorsEqual(color, c)
      undefined

    # Return the map index or color proportional to the value between min, max.
    # This is a linear interpolation based on the map indices.
    # The optional minColor, maxColor args are for using a subset of the map.
    scaleIndex: (number, min, max, minColor = 0, maxColor = @length-1) ->
      scale = u.lerpScale number, min, max # (number-min)/(max-min)
      Math.round(u.lerp minColor, maxColor, scale)
    scaleColor: (number, min, max, minColor = 0, maxColor = @length-1) ->
      @[ @scaleIndex number, min, max, minColor, maxColor ]

    # Find closest index/value in an RGB color cube by direct lookup in cube.
    # Much faster than more general findClosest. Error if not cube
    closestCubeIndex: (r, g, b) ->
      u.error "closestCubeIndex: not a color cube" if not @cube
      step = 255/(@cube-1)
      [rLoc, gLoc, bLoc] = (Math.round(c/step) for c in [r, g, b])
      rLoc + gLoc*@cube + bLoc*@cube*@cube
    closestCubeColor: (r, g, b) -> @[ @closestCubeIndex r, g, b ]

    # Find the index/color closest to this r,g,b; using Color.rgbDistance.
    # Note: slow for large maps unless color cube or in index or exact match.
    findClosestIndex: (r, g, b) -> # alpha not in rgbDistance function
      return @closestCubeIndex r, g, b if @cube
      return ix if ( ix=@lookup(Color.arrayToColor [r,g,b], @type) )
      # return ix if @index and ( ix=@lookup(Color.arrayToColor [r,g,b], @type) )
      minDist = Infinity
      ixMin = 0
      for color, i in @
        [r0, g0, b0] = Color.colorToArray color
        d = Color.rgbDistance r0, g0, b0, r, g, b
        if d < minDist
          minDist = d
          ixMin = i
      ixMin
    findClosestColor: (r, g, b) ->  @[ @findClosestIndex r, g, b ]

  # Utilities for creating color maps, inspired [by this repo](
  # https://github.com/bpostlethwaite/colormap).
  # Do *not* call these with "new", they will call new Colormap themselves.

  # Ask the browser to use the canvas gradient feature
  # to create nColors given the gradient color stops and locs.
  #
  # Stops are css strings or rgba arrays. Locs are floats from 0-1
  #
  # This is a really powerful technique, see:
  #
  # * [Mozilla Gradient Doc](
  #   https://developer.mozilla.org/en-US/docs/Web/CSS/linear-gradient)
  # * [Colorzilla Gradient Editor](
  #   http://www.colorzilla.com/gradient-editor/)
  # * [GitHub ColorMap Project](
  #   https://github.com/bpostlethwaite/colormap)

  gradientUint8Array: (nColors, stops, locs) ->
    # Convert css versions of the stops if they are rgb arrays
    stops = (Color.arrayToColor a, "css" for a in stops) if u.isArray stops[0]
    locs = u.aRamp 0, 1, stops.length if not locs?
    ctx = u.createCtx nColors, 1
    grad = ctx.createLinearGradient 0, 0, nColors, 0
    grad.addColorStop locs[i], stops[i] for i in [0...stops.length]
    ctx.fillStyle = grad
    ctx.fillRect 0, 0, nColors, 1
    u.ctxToImageData(ctx).data
  # gradientRgbaArray: (nColors, stops, locs) ->
  #   id = @gradientUint8Array nColors, stops, locs
  #   ( [ id[i], id[i+1], id[i+2], id[i+3] ] for i in [0...id.length] by 4 )
  gradientUint8sArray: (nColors, stops, locs) ->
    @uintArrayToUint8s(@gradientUint8Array nColors, stops, locs)
  gradientPixelArray: (nColors, stops, locs) ->
    new Uint32Array( @gradientUint8Array(nColors, stops, locs).buffer )

  # Convert Uint8Array into Array of 4 element uint8s subarrays.
  # Useful converting ImageData objects like gradients to color arrays.
  uintArrayToUint8s: (uint8Array) ->
    ( uint8Array.subarray(i,i+4) for i in [0...uint8Array.length] by 4 )


  # Utility to permute 3 arrays.
  #
  # * If any arg is array, no change made.
  # * If any arg is 1, replace with [max].
  # * If any arg is n>1, replace with u.aIntRamp(0,max,n).
  #
  # Resulting array is an array of arrays of len 3 permuting A1, A2, A3
  # Used by rgbColorMap and hslColorMap
  permuteColors: (A1, A2=A1, A3=A2, max=[255,255,255]) ->
    [A1, A2, A3] = for A, i in [A1, A2, A3] # multi-line comprehension
      if typeof A is "number"
        if A is 1 then [max[i]] else u.aIntRamp(0, max[i], A)
      else A
    @permuteArrays A1, A2, A3
  # Permute simple arrays w/o conversions above.
  permuteArrays: (A1, A2=A1, A3=A2) ->
    array = []
    ((array.push [a1,a2,a3] for a1 in A1) for a2 in A2) for a3 in A3
    array

  # Create a gray map of gray values (gray: r=g=b)
  # These are typically 256 entries but can be smaller
  # by passing a size parameter.
  grayArray: (size = 256) -> ( [i,i,i] for i in u.aIntRamp 0, 255, size )
  grayColorMap: (size=256, type="typed", indexToo=false) ->
    new @ColorMap @grayArray(size), type, indexToo

  # Create a colormap by permuted rgb values. R, G, B can be either a number,
  # (the number of steps beteen 0-255), or an array of values to use
  # for the color.  Ex: R = 3, corresponds to [0, 128, 255]
  # The resulting map permutes the R, G, V values.  Thus if
  # R=G=B=4, the resulting map has 4*4*4=64 colors.
  rgbColorMap: (R, G=R, B=R, type="typed", indexToo=true) ->
    if (typeof R is "number") and (R is G is B)
      new @ColorMap R, type, indexToo # lets ColorMap know its a color cube
    else
      new @ColorMap @permuteColors(R, G, B), type, indexToo

  # Create an hsl map, inputs similar to above.  Convert the
  # HSL values to css, default to bright hue ramp.
  hslColorMap: (H, S=1, L=1, type="css", indexToo=false) ->
    hslArray = @permuteColors(H, S, L, [359,100,50])
    cssArray = (Color.hslString a... for a in hslArray)
    new @ColorMap cssArray, type, indexToo

  # Use gradient to build an rgba array, then convert to colormap
  gradientColorMap: (nColors, stops, locs, type="typed", indexToo=true) ->
    new @ColorMap @gradientUint8sArray(nColors, stops, locs), type, indexToo

  # Create a map with a random set of colors.
  # Sometimes useful to sort by intensity afterwards.
  randomColorMap: (nColors, type="typed", indexToo=false) ->
    # new @ColorMap (Color.randomRgba() for i in [0...nColors]), type, indexToo
    new @ColorMap (Color.randomRgb() for i in [0...nColors]), type, indexToo

  # Create alpha map of the given base r,g,b color,
  # with nOpacity opacity values, default to all 256
  alphaColorMap: (rgb, nOpacities = 256, type="typed", indexToo=true) ->
    alphaArray = ( u.clone(rgb).push a for a in u.aIntRamp 0, 255, nOpacities )
    new @ColorMap alphaArray rgb, nOpacities, type, indexToo

# ### Two prototype conversion primitive color maps.

  # Factory: convert JS array of valid colors to color map via prototype.
  # Will have the type of the first element, and no index nor be a color cube.
  # It will not create a new array but mutate the input array.
  protoMap: (array) ->
    array.type = Color.colorType(array[0])
    array.__proto__ = ColorMap.prototype
    array # this is just the original array, returned for convenience.

  # Create a color map via the 140 html standard css color names
  # or any of the other forms of css color strings.
  # The input is an array of css strings.
  cssProtoMap: (strings) -> @protoMap strings
  # Equivalent to ColorMap w/ these defaults. Use this for modifying options.
  cssColorMap: (strings, type="css", indexToo=false) ->
    new @ColorMap strings, type, indexToo

  # Create a color map via an array of pixels, gradientPixelArray for example.
  # If you don't have pixel data, call rgbColorMap with type="pixel"
  # or simply create your own via:
  #
  #    pixels = ( rgbaToPixel rgba... for rgba in rgbas )
  pixelProtoMap: (pixels) -> @protoMap pixels
  # Equivalent to ColorMap w/ these defaults. Use this for modifying options.
  pixelColorMap: (pixels, type="pixel", indexToo=false) ->
    new @ColorMap pixels, type, indexToo

}
