# ### Color Maps

# A colormap is an array of colors. A ColorMapProto is provided
# to simplify access to the colormap's colors.
#
# Maps are extremely useful:
#
# * Performance: Maps are created once, reducing the calls to primitives
#   whenever a color is changed.
# * Space Effeciency: They *vastly* reduce the number of colors used.
# * Data: Their index provides a MatLab/NumPy/NetLogo "color as data" feature.
#   Ex: "Heat" may be mapped to a gradient from green to red.
#
# And you can simply make your own array of legal colors, works fine.

ColorMaps  = {

# ### Color Array Utilities
# Several utilities for creating color arrays

# ### Gradients

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

  gradientImageData: (nColors, stops, locs) ->
    # Convert css versions of the stops if they are rgb arrays
    stops = (Color.arrayToColor a, "css" for a in stops) if u.isArray stops[0]
    locs = u.aRamp 0, 1, stops.length if not locs?
    ctx = u.createCtx nColors, 1
    grad = ctx.createLinearGradient 0, 0, nColors, 0
    grad.addColorStop locs[i], stops[i] for i in [0...stops.length]
    ctx.fillStyle = grad
    ctx.fillRect 0, 0, nColors, 1
    u.ctxToImageData(ctx).data

# ### Array Conversion Utilities

  # Convert Uint8Array into Array of 4 element Uint8s subarrays,
  # 4 element JS Arrays, or colors.
  # Useful for converting ImageData objects like gradients to color arrays.
  uint8ArrayToUint8s: (a) ->
    ( a.subarray(i,i+4) for i in [0...a.length] by 4 )
  uint8ArrayToRgbas: (a) ->
    ( [ a[i], a[i+1], a[i+2], a[i+3] ] for i in [0...a.length] by 4 )

  # Convert Uint8 typed array into colors
  uint8ArrayToColors: (array, type) ->
    return new Uint32Array( array.buffer ) if type is "pixel"
    @arrayToColors(@uint8ArrayToUint8s(array), type)

  # Convert array of colors or rgba arrays to array of colors of given type
  arrayToColors: (array, type) ->
    return array if Color.colorType(array[0]) is type
    array[i] = Color.convertColor(a, type) for a,i in array
    array

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

# ### ColorMaps

  # Convert an array of colors to a colormap.
  # Returns the original array, just for convenience.
  colorMap: (array, indexToo = false) ->
    array.__proto__ = @ColorMapProto
    array.init indexToo

  # Use prototypal inheritance for converting array to colormap.
  ColorMapProto: {
    __proto__: Array
    init: (indexToo = false) ->
      @type = Color.colorType @[0]
      @index = {} if indexToo
      u.error "ColorMap type error" unless @type
      if @type is "typed"
        for color,i in @ then color.ix = i; color.map = @
      @index[ @indexKey(color) ] = i for color,i in @ if @index
      @ # this is just the original array, returned for convenience.

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
      Array.prototype.sort.call @, compareFcn
      @index[ @indexKey(color) ] = i for color,i in @ if @index
      color.ix = i for color,i in @ if @type is "typed"
      @

    # Lookup color in map, returning index or undefined if not found
    lookup: (color) ->
      color = Color.convertColor color, @type # make sure color is our type
      return @index[ @indexKey(color) ] if @index
      for c,i in @ then return i if @colorsEqual(color, c)
      undefined

    # Return the map index or color proportional to the value between min, max.
    # This is a linear interpolation based on the map indices.
    # The optional minColor, maxColor args are for using a subset of the map.
    scaleIndex: (number, min, max, minColor = 0, maxColor = @length-1) ->
      scale = u.lerpScale number, min, max # (number-min)/(max-min)
      Math.round(u.lerp minColor, maxColor, scale)
    scaleColor: (number, min, max, minColor = 0, maxColor = @length-1) ->
      @[ @scaleIndex number, min, max, minColor, maxColor ]

    # Find the index/color closest to this r,g,b
    # Note: slow for large maps unless color cube or exact match.
    findClosestIndex: (r, g, b) -> # alpha not in rgbDistance function
      # First directly find if rgb cube
      if @cube
        step = 255/(@cube-1)
        [rLoc, gLoc, bLoc] = (Math.round(c/step) for c in [r, g, b])
        return rLoc + gLoc*@cube + bLoc*@cube*@cube
      # Then check if is exact match
      return ix if ix = @lookup [r,g,b]
      # Finally use color distance to find closest color
      minDist = Infinity; ixMin = 0
      for color, i in @
        [r0, g0, b0] = Color.colorToArray color
        d = Color.rgbDistance r0, g0, b0, r, g, b
        if d < minDist then minDist = d; ixMin = i
      ixMin
    findClosestColor: (r, g, b) ->  @[ @findClosestIndex r, g, b ]
  }

# ### ColorMap Utilities
# Utilities for creating color arrays and associated maps

  # Convert any array of rgb(a) or color values into colormap.
  # Good for converting css names, pixels/image data
  basicColorMap: (array, type="typed", indexToo=false) ->
    array = @arrayToColors array, type
    @colorMap array, indexToo

  # Create a gray map of gray values (gray: r=g=b)
  # These are typically 256 entries but can be smaller
  # by passing a size parameter.
  grayColorMap: (size=256, type="typed", indexToo=false) ->
    array = ( [i,i,i] for i in u.aIntRamp 0, 255, size )
    @basicColorMap array, type, indexToo

  # Create a map with a random set of colors.
  # Sometimes useful to sort by intensity afterwards.
  randomColorMap: (nColors, type="typed", indexToo=false) ->
    array = (Color.randomRgb() for i in [0...nColors])
    @basicColorMap array, type, indexToo

  # Create a colormap by permuted rgb values.
  #
  # R, G, B can be either a number, (the number of steps beteen 0-255),
  # or an array of values to use for the color.
  #
  # Ex: R = 3, corresponds to R = [0, 128, 255]
  #
  # The resulting map permutes the R, G, B values.  Thus if
  # R=G=B=4, the resulting map has 4*4*4=64 colors.
  rgbColorArray: (R, G, B, type) ->
    array = @permuteColors(R, G, B)
    array.cube = R if (typeof R is "number") and (R is G is B)
    @arrayToColors array, type
  rgbColorMap: (R, G=R, B=R, type="typed", indexToo=true) ->
    @colorMap @rgbColorArray(R, G, B, type), indexToo

  # Create an hsl map, inputs similar to above.  Convert the
  # HSL values to css, default to bright hue ramp.
  hslColorArray: (H, S, L, type) ->
    hslArray = @permuteColors(H, S, L, [359,100,50])
    array = (Color.hslString a... for a in hslArray)
    @arrayToColors array, type
  hslColorMap: (H, S=1, L=1, type="css", indexToo=false) ->
    @colorMap @hslColorArray(H, S, L, type), indexToo

  # Use gradient to build an rgba array, then convert to colormap.
  # This easily creates all the MatLab colormaps.
  gradientColorArray: (nColors, stops, locs, type) ->
    id = @gradientImageData(nColors, stops, locs)
    @uint8ArrayToColors id, type
  gradientColorMap: (nColors, stops, locs, type="typed", indexToo=true) ->
    array = @gradientColorArray nColors, stops, locs, type
    @colorMap array, indexToo

  # Create alpha map of the given base r,g,b color,
  # with nOpacity opacity values, default to all 256
  alphaColorArray: (rgb, nOpacities, type) ->
    [r, g, b] = rgb
    array = ( [r, g, b, a] for a in u.aIntRamp 0, 255, nOpacities )
    @arrayToColors array, type
  alphaColorMap: (rgb, nOpacities = 256, type="typed", indexToo=false) ->
    array = @alphaColorArray rgb, nOpacities, type
    @colorMap array, indexToo

}
