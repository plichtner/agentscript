# This module contains these color topics:
#
# * The two browser color types: pixels and strings
# * A typedColor: A Uint8 (clamped) r,g,b,a TypedArray
#   with both rgba and pixel views onto the same buffer,
#   and, optionally, the associated css string.
# * A color map class and several colormap "factories"
# * Several simple core color primitive functions
#
# In the functions below, rgba values are ints in 0-255, including a.
#
# Note a is not in 0-1 as in css colors.
#
# Naming convention: rgba/array is generally a 3 or 4 element JavaScript
# Array thus not a browser color.
# Instead, it is used internally for functions taking r, g, b, a=255
# color values.
#
# There are *many* other common color representations, such as
# a TypedArray of 4 floats in 0-1 (webgl),
# and other odd mixtures of values, some in degrees, some in percentages.
#
# We restrict ourselves to css color strings, 32 bit integer pixels,
# and 4 element Uint8 TypedColors.

Color = {

  # These are the types of colors we support
  ColorTypes: {
    css: "css"      # a legal css color string
    pixel: "pixel"  # a Uint32 r,g,b,a with correct endianness
    typed: "typed"  # a Uint8 typed array with additional properties
  }
  # Return the color type of a given color
  colorType: (color) ->
    if u.isString color then return "css"
    if u.isInteger color then return "pixel"
    if color.pixelArray then return "typed"
    # safe to call with non-color; useful for testing if color *is* a color.
    null
  # Validate the color type
  isValidType: (type) -> @ColorTypes[type]?
  checkType: (type) ->
    u.error "Bad color type #{type}" if not @isValidType type
  # Validate "array" which can be standard or typed array of length 3 or 4
  isValidArray: (array) ->
    (u.isArray(array) or array.buffer) and (array.length in [3..4])
  checkArray: (array) ->
    u.error "Bad array: #{array}/#{array.length}" if not @isValidArray array
  # Return new color of the given type, given an r,g,b,(a) array,
  # where a defaults to opaque (255).
  # The array can be a JavaScript Array, a TypedArray, or a TypedColor
  arrayToColor: (array, type) ->
    @checkArray(array)
    @checkType(type)
    switch type
      when "css" then return @triString array...
      when "pixel" then return @rgbaToPixel array...
      when "typed" then return @typedColor array...
    u.error "arrayToColor problem"
  # Return array (either typed or Array) representing the color.
  # With this and the above, all color permutations are possible,
  # i.e. a css string can be converted to a typed color:
  #
  #    Color.arrayToColor(Color.colorToArray("red"), "typed")
  colorToArray: (color) ->
    type = @colorType(color)
    switch type
      when "css" then return @stringToUint8s color # @stringToRgba color
      when "pixel" then return @pixelToRgba color # @stringToUint8s color # @stringToRgba color
      when "typed" then return color # already a (typed) array
  # Speaking of which: Convert color to a color of a new type.
  # Return color if color is already of type.
  convertColor: (color, type) ->
    return color if @colorType(color) is type
    @arrayToColor(@colorToArray(color), type)

  # Return a random color of the given type
  randomColor: (type="typed") -> @arrayToColor(@randomRgba(), type)
  # Hopefully temporary .. convert to 3 or 4 element array with alpha in 0-1
  legacyColor: (color) ->
    array = Array(@colorToArray(color)...)
    if array[3] is 255 then array.pop() else array[3] /= 255
    array




# ### CSS Color Strings.

  # CSS colors in HTML are strings, see [legal CSS string colors](
  # http://www.w3schools.com/cssref/css_colors_legal.asp)
  # and [Mozilla's Color Reference](
  # https://developer.mozilla.org/en-US/docs/Web/CSS/color_value)
  # as wall as the [future CSS4](http://dev.w3.org/csswg/css-color/) spec.
  #
  # The strings can be may forms:
  #
  # * Names: [140 color case-insensitive names](
  #   http://en.wikipedia.org/wiki/Web_colors#HTML_color_names) like CadetBlue
  # * Hex, short and long form: #0f0, #ff10a0
  # * RGB: rgb(255, 0, 0), rgba(255, 0, 0, 0.5)
  # * HSL: hsl(120, 100%, 50%), hsla(120, 100%, 50%, 0.8)

  # Legacy: Check alpha to be int in 0-255, not float in (0-1].
  # The name is the function, for clearer error message in console.
  # This will be romoved after integration into a few applications
  checkAlpha: (name, a) ->
    if 0 < a <= 1 # well, 1 *could* be OK, it's in 0-255.
      console.log "#{name}: a=#{a}. Alpha float in (0-1], not int in [0-255]"

  # Convert 4 r,g,b,a ints in [0-255] to a css color string.
  # Alpha "a" is int in [0-255], not the "other alpha" float in 0-1
  rgbaString: (r, g, b, a=255) ->
    @checkAlpha "rgbaString", a
    a = a/255; a4 = a.toPrecision(4)
    if a is 1 then "rgb(#{r},#{g},#{b})" else "rgba(#{r},#{g},#{b},#{a4})"

  # Convert 3 ints, h in [0-360], s,l in [0-100]% to a css color string.
  # Alpha "a" is int in [0-255].
  #
  # Note h=0 and h=360 are the same, use h in 0-359 for unique colors.
  hslString: (h, s, l, a=255) ->
    @checkAlpha "hslString", a
    a = a/255; a4 = a.toPrecision(4)
    if a is 1 then "hsl(#{h},#{s}%,#{l}%)" else "hsla(#{h},#{s}%,#{l}%,#{a4})"

  # Return a web/html/css hex color string for an r,g,b opaque color.
  # Identical color will be drawn as if using rgbaString above
  # but without an alpha capability. Both #nnn and #nnnnnn forms supported.
  # Default is to check for the short hex form: #nnn.
  hexString: (r, g, b, shortOK=true) ->
    if shortOK
      if u.isInteger(r0=r/17) and u.isInteger(g0=g/17) and u.isInteger(b0=b/17)
        return @hexShortString r0, g0, b0
    "#" + (0x1000000 | (b | g << 8 | r << 16)).toString(16).slice(-6)
  # Return the 4 char short version of a hex color.  Each of the r,g,b values
  # must be in [0-15].  The resulting color will be equivalent
  # to r*17, g*17, b*17, resulting in the values:
  #
  #     0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255
  #
  # This is equivalent u.aRamp(0,255,16), i.e. 16 values per rgb channel.
  hexShortString: (r, g, b) ->
    if (r>15) or (g>15) or (b>15)
      u.error "hexShortString: one of #{[r,g,b]} > 15"
    "#" + r.toString(16) + g.toString(16) + b.toString(16)

  # This is a hybrid string and the generally our default.  It returns:
  #
  # * rgbString if a not 255 (i.e. not opaque)
  # * hexString otherwise
  # * with the hexShortString if appropriate
  triString: (r, g, b, a=255) ->
    @checkAlpha "triString", a
    if a is 255 then @hexString(r, g, b, true) else @rgbaString(r, g, b, a)

# ### CSS String Conversions

  # Return 4 element array given any legal CSS string color
  # [legal CSS string color](
  # http://www.w3schools.com/cssref/css_colors_legal.asp)
  #
  # Legal strings vary widely: CadetBlue, #0f0, rgb(255,0,0), hsl(120,100%,50%)
  #
  # Note: The browser speaks for itself: we simply set a 1x1 canvas fillStyle
  # to the string and create a pixel, returning the r,g,b,a typedColor
  # Odd results if string is not recognized by browser.

  # The shared 1x1 canvas 2D context.
  sharedCtx1x1: u.createCtx 1, 1 # share across calls.
  # Convert css string to shared typed array
  stringToUint8s: (string) -> # string = string.toLowerCase()?
    @sharedCtx1x1.clearRect 0, 0, 1, 1 # is this needed?
    @sharedCtx1x1.fillStyle = string
    @sharedCtx1x1.fillRect 0, 0, 1, 1
    @sharedCtx1x1.getImageData(0, 0, 1, 1).data
  # Convert css string to JavaScript array
  stringToRgba: (string) ->
    new Array @stringToUint8s(string)...
  # # Convert css string to pixel
  # stringToPixel: (string) -> @rgbaToPixel @stringToUint8s(string)...


  # Similarly, ask the browser to use the canvas gradient feature
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

  gradientDataArray: (nColors, stops, locs) ->
    # Convert css versions of the stops if they are rgb arrays
    stops = (@arrayToColor a, "css" for a in stops) if u.isArray stops[0]
    locs = u.aRamp 0, 1, stops.length if not locs?
    ctx = u.createCtx nColors, 1
    grad = ctx.createLinearGradient 0, 0, nColors, 0
    grad.addColorStop locs[i], stops[i] for i in [0...stops.length]
    ctx.fillStyle = grad
    ctx.fillRect 0, 0, nColors, 1
    u.ctxToImageData(ctx).data
  gradientRgbaArray: (nColors, stops, locs) ->
    id = @gradientDataArray nColors, stops, locs
    ( [ id[i], id[i+1], id[i+2], id[i+3] ] for i in [0...id.length] by 4)
  gradientPixelArray: (nColors, stops, locs) ->
    new Uint32Array( @gradientDataArray(nColors, stops, locs).buffer )

# ### Pixel Colors.

  # Primitive Rgba<>Pixel manipulation.
  #
  # These use two views onto a 4 byte typed array buffer.
  # initSharedPixel called after Color literal object exists,
  # see why at [Stack Overflow](http://goo.gl/qrHXwB)

  sharedPixel: null
  sharedUint8s: null
  initSharedPixel: ->
    @sharedPixel = new Uint32Array(1)
    @sharedUint8s = new Uint8ClampedArray(@sharedPixel.buffer)

  # Convert r,g,b,a to a single Uint32 pixel, correct endian format.
  rgbaToPixel: (r, g, b, a=255) ->
    @sharedUint8s[i] = [r, g, b, a][i] for i in [0..3]
    @sharedPixel[0]

  # Convert a pixel to the shared rgba uInt8 typed view.
  # Good for one-time computations like finding the pixel r,g,b,a values.
  # Use pixelToRgba below if you need a persistant copy of the shared color
  pixelToUint8s: (pixel) ->
    @sharedPixel[0] = pixel
    @sharedUint8s

  # Convert a pixel to a new JavaScript array
  pixelToRgba: (pixel) -> new Array(@pixelToUint8s(pixel)...)

# ### Color Conversion and Scaling Functions.

  # Return the gray/intensity float value for a given r,g,b color
  # Use Math.round to convert to 0-255 int for gray color value.
  # [Good post on image filters](
  # http://www.html5rocks.com/en/tutorials/canvas/imagefilters/)
  rgbIntensity: (r, g, b) -> 0.2126*r + 0.7152*g + 0.0722*b

  # RGB <> HSL (Hue, Saturation, Lightness) conversions.
  #
  # r,g,b are ints in [0-255], i.e. 3 unsigned bytes of a pixel.
  # h int in [0-360] degrees; s,l ints [0-100] percents; (h=0 same as h=360)
  # See [Wikipedia](http://en.wikipedia.org/wiki/HSV_color_space)
  # and [Blog Post](
  # http://axonflux.com/handy-rgb-to-hsl-and-rgb-to-hsv-color-model-c)
  #
  # This is a [good table of hues](
  # http://dev.w3.org/csswg/css-color/#named-hue-examples)
  # and this is the [W3C HSL standard](
  # http://www.w3.org/TR/css3-color/#hsl-color)
  #
  # Note that HSL is [not the same as HSB/HSV](
  # http://en.wikipedia.org/wiki/HSL_and_HSV)

  # Convert r,g,b to [h,s,l] Array. Note opaque, no "a" value
  rgbToHsl: (r, g, b) ->
    r = r/255; g = g/255; b = b/255
    max = Math.max(r,g,b); min = Math.min(r,g,b)
    sum = max + min; diff = max - min
    l = sum/2 # lightness is the average of the largest and smallest rgb's
    if max is min
      h = s = 0 # achromatic, a shade of gray
    else
      s = if l > 0.5 then diff/(2-sum) else diff/sum
      switch max
        when r then h = ((g - b) / diff) + (if g < b then 6 else 0)
        when g then h = ((b - r) / diff) + 2
        when b then h = ((r - g) / diff) + 4
    [Math.round(360*h/6), Math.round(s*100), Math.round(l*100)]

  # Convert h,s,l to r,g,b Array via stringToUint8s
  hslToRgb: (h, s, l) ->
    str = @hslString(h, s, l)
    @stringToUint8s(str).subarray(0,3) # a 3 byte view onto the 4 byte buffer.

  # Return a [distance metric](
  # http://www.compuphase.com/cmetric.htm) between two colors.
  # Max distance is roughly 765 (3*255), between black & white.
  rgbDistance: (r1, g1, b1, r2, g2, b2) ->
    rMean = Math.round( (r1 + r2) / 2 )
    [dr, dg, db] = [r1 - r2, g1 - g2, b1 - b2]
    Math.sqrt (((512+rMean)*dr*dr)>>8) + (4*dg*dg) + (((767-rMean)*db*db)>>8)

  # A very crude way to scale a data value to an rgb color.
  # value is in [min max], rgb's are two colors.
  # See ColorMap.scaleColor for preferred method
  rgbLerp: (value, min, max, rgb1, rgb0 = [0,0,0]) ->
    scale = u.lerpScale value, min, max #(value - min)/(max - min)
    (Math.round(u.lerp(rgb0[i], rgb1[i], scale))) for i in [0..2]

  # Return rgb array with 3 random ints in 0-255.
  randomRgb: -> (u.randomInt(256) for i in [0..2])
  # Return rgba array with random rgb values, with "a" a constant opacity
  randomRgba: (a=255)->
    color = @randomRgb()
    color.push a
    color

# ### Typed Color

  # A typed color is a typed array with r,g,b,a in 0-255 and optional
  # css string. As usual, a is in 0-255, *not* in 0-1 as in some color formats.
  #
  # Return a 4 element Uint8ClampedArray, with two properties:
  #
  # * pixelArray: A single element Uint32Array view on the Uint8ClampedArray
  # * str: an optional, lazy evaluated, css color string.
  #
  # Any change to the typedColor r,g,b,a elements will dynamically change
  # the pixel value as it is a view onto the same buffer.
  #
  # Setting the pixelArray[0] also dynamically changes all 4 r,g,b,a, values.
  # See [Mozilla Docs](http://goo.gl/3OOQzy)
  #
  # TypedColors are used in canvas's [ImageData pixels](
  # https://developer.mozilla.org/en-US/docs/Web/API/ImageData),
  # WebGL colors (4 rgba floats in 0-1), and in images.

  typedColor: do () ->
     # This [IIFE (history)](http://goo.gl/FxVFe)
     # creates a proto with an Uint proto, which is in turn
     # set to the proto of the typedColor function.  Whew!
     # This allows TypedArrays to have prototype properties,
     # including Object.defineProperties without enlarging them.
    # typedColor = (r, g, b, a=255, stringToo=true) ->
    typedColor = (r, g, b, a=255) ->
      Color.checkAlpha "typedColor", a
      ua = new Uint8ClampedArray([r,g,b,a])
      ua.pixelArray = new Uint32Array(ua.buffer)
      # lazy evaluation will set the css string for this typed array:
      #
      #     ua.string = Color.triString(r, g, b, a)
      #
      # do not set the ua.string directly, will get typed values out of sync.

      # Make me an instance of TypedColorProto
      ua.__proto__ = TypedColorProto
      ua
    TypedColorProto = {
      # Return string representation of typedColor, mainly console debugging.
      toString: -> "typedColor:#{Array(@...).toString()};css=#{@string ? null}"
      # Set the typed array; no need for getColor, it *is* the typed Uint8 array
      setColor: (r,g,b,a=255) ->
        [@[0], @[1], @[2], @[3]] = [r,g,b,a]
        @string = null if @string # will be lazy evaluated via getString.
      # Set the pixel view, thus changing the array (Uint8) view
      setPixel: (pixel)->
        @pixelArray[0]=pixel
        @string = null if @string # will be lazy evaluated via getString.
      # Get the pixel value, i.e. pixelArray[0]
      getPixel: -> @pixelArray[0]
      # Set both Typed Arrays to equivalent pixel/rgba values of the string.
      #
      # Does *not* set the @string, it will be lazily evaluated to its
      # triString. This lets the typedColor remain small without the
      # color string until required by getters.
      #
      # Note if you set string to "red" or "rgb(255,0,0)", the resulting
      # css string (triString) value will still return the standard #f00
      setString: (string) ->
        @setColor(Color.stringToUint8s(string)...)
      # Return the triString for this typedColor, setting the @string value
      getString: (string) ->
        @string = Color.triString(@...) unless @string
        @string
    }
    # Set TypedColorProto proto to be Uint8ClampedArray's prototype
    TypedColorProto.__proto__ = Uint8ClampedArray.prototype
    # Sugar for pixel, rgba, string properties.
    # Note these are in TypedColorProto, not in the typedColor, thus shared.
    Object.defineProperties TypedColorProto,
    # pixel: get/set typedColor.pixelArray[0] via pixel property
      "pixel":
        get: -> @pixelArray[0]
        set: (val) -> @setPixel(val)
        enumerable: true # make visible in stack trace, remove after debugging
    # rgba: get/set Uint8 values via JavaScript Array
      "rgba":
        get: -> [@[0], @[1], @[2], @[3]]
        set: (val) -> @setColor(val...)
        enumerable: true # make visible in stack trace, remove after debugging
    # css: get/set typedColor.str via @string property. Updates TypedArrays.
    # Note the str getter property lazily sets @string.
      "css":
        get: -> @getString()
        set: (val) -> @setString(val)
        enumerable: true # make visible in stack trace, remove after debugging
    # str: legacy usage, identical to css, will remove
      "str":
        get: -> @getString()
        set: (val) -> @setString(val)
        enumerable: true # make visible in stack trace, remove after debugging
    typedColor

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
        colorsArray = Color.permuteColors @cube
      type0 = Color.colorType(colorsArray[0])
      if type0 and (type0 isnt type)
        console.log "Primitive color conversion in color map. OK?"
        colorsArray = (Color.colorToArray(c) for c in colorsArray)
      # After this, colorsArray has arrays or colors matching type
      @appendColor color, type for color in colorsArray

    # Append a color to the the map. color is either an array or a valid color.
    # If index object exists keep an index entry pointing to the color index.
    # If type is "typed" add map, index properties to each typedColor.
    appendColor: (color) ->
      if Color.isValidArray color # ToDo: better to use type comparison?
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

    # Get a random index or color from this map
    randomIndex: -> u.randomInt @length
    randomColor: -> @[ @randomIndex() ]

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
    new ColorMap @grayArray(size), type, indexToo

  # Create a colormap by rgb values. R, G, B can be either a number,
  # the number of steps beteen 0-255, or an array of values to use
  # for the color.  Ex: R = 3, corresponds to [0, 128, 255]
  # The resulting map permutes the R, G, V values.  Thus if
  # R=G=B=4, the resulting map has 4*4*4=64 colors.
  rgbColorMap: (R, G=R, B=R, type="typed", indexToo=true) ->
    if (typeof R is "number") and (R is G is B)
      new ColorMap R, type, indexToo # lets ColorMap know its a color cube
    else
      new ColorMap @permuteColors(R, G, B), type, indexToo

  # Create an hsl map, inputs similar to above.  Convert the
  # HSL values to css, default to bright hue ramp.
  hslColorMap: (H, S=1, L=1, type="css", indexToo=false) ->
    hslArray = @permuteColors(H, S, L, [359,100,50])
    cssArray = (@hslString a... for a in hslArray)
    new ColorMap cssArray, type, indexToo

  # Use gradient to build an rgba array, then convert to colormap
  gradientColorMap: (nColors, stops, locs, type="typed", indexToo=true) ->
    new ColorMap @gradientRgbaArray(nColors, stops, locs), type, indexToo

  # Create a map with a random set of colors.
  # Sometimes useful to sort by intensity afterwards.
  randomColorMap: (nColors, type="typed", indexToo=false) ->
    new ColorMap (@randomRgba() for i in [0...nColors]), type, indexToo

  # Create alpha map of the given base r,g,b color,
  # with nOpacity opacity values, default to all 256
  alphaColorMap: (rgb, nOpacities = 256, type="typed", indexToo=true) ->
    alphaArray = ( u.clone(rgb).push a for a in u.aIntRamp 0, 255, nOpacities )
    new ColorMap alphaArray rgb, nOpacities, type, indexToo

# ### Two prototype conversion primitive color maps.

  # Factory: convert JS array of valid colors to color map via prototype.
  # Will have the type of the first element, and no index nor be a color cube.
  protoMap: (array) ->
    array.__proto__ = ColorMap.prototype
    array.type = @colorType(array[0])
    array # this is just the original array, returned for convenience.

  # Create a color map via the 140 html standard colors
  # or any of the other forms of css color strings.
  # The input is an array of css strings.
  nameProtoMap: (strings) -> @protoMap strings
  # Equivalent to ColorMap w/ these defaults. Use this for modifying options.
  nameColorMap: (strings, type="css", indexToo=false) ->
    new ColoMap strings, type, indexToo

  # Create a color map via an array of pixels, gradientPixelArray for example.
  # If you don't have pixel data, call rgbColorMap with type="pixel"
  # or simply create your own via:
  #
  #    pixels = ( rgbaToPixel rgba... for rgba in rgbas )
  pixelProtoMap: (pixels) -> @protoMap pixels
  # Equivalent to ColorMap w/ these defaults. Use this for modifying options.
  pixelColorMap: (pixels, type="pixel", indexToo=false) ->
    new ColorMap pixels, type, indexToo

};
Color.initSharedPixel() # Initialize the shared buffer pixel/rgb view

# Here are the 140 case insensitive legal color names (the X11 set)
# To include them in your model, use:
#
#     namedColorString = "AliceBlue AntiqueWhite Aqua Aquamarine Azure Beige Bisque Black BlanchedAlmond Blue BlueViolet Brown BurlyWood CadetBlue Chartreuse Chocolate Coral CornflowerBlue Cornsilk Crimson Cyan DarkBlue DarkCyan DarkGoldenRod DarkGray DarkGreen DarkKhaki DarkMagenta DarkOliveGreen DarkOrange DarkOrchid DarkRed DarkSalmon DarkSeaGreen DarkSlateBlue DarkSlateGray DarkTurquoise DarkViolet DeepPink DeepSkyBlue DimGray DodgerBlue FireBrick FloralWhite ForestGreen Fuchsia Gainsboro GhostWhite Gold GoldenRod Gray Green GreenYellow HoneyDew HotPink IndianRed Indigo Ivory Khaki Lavender LavenderBlush LawnGreen LemonChiffon LightBlue LightCoral LightCyan LightGoldenRodYellow LightGray LightGreen LightPink LightSalmon LightSeaGreen LightSkyBlue LightSlateGray LightSteelBlue LightYellow Lime LimeGreen Linen Magenta Maroon MediumAquaMarine MediumBlue MediumOrchid MediumPurple MediumSeaGreen MediumSlateBlue MediumSpringGreen MediumTurquoise MediumVioletRed MidnightBlue MintCream MistyRose Moccasin NavajoWhite Navy OldLace Olive OliveDrab Orange OrangeRed Orchid PaleGoldenRod PaleGreen PaleTurquoise PaleVioletRed PapayaWhip PeachPuff Peru Pink Plum PowderBlue Purple Red RosyBrown RoyalBlue SaddleBrown Salmon SandyBrown SeaGreen SeaShell Sienna Silver SkyBlue SlateBlue SlateGray Snow SpringGreen SteelBlue Tan Teal Thistle Tomato Turquoise Violet Wheat White WhiteSmoke Yellow YellowGreen"
#     namedColors = namedColorString.split(" ")
