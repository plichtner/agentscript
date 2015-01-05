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
# and 4 element Uint8 TypedColors (in ColorTypes module)

Color = {

# ### CSS Color Strings.

  # CSS colors in HTML are strings, see [legal CSS string colors](
  # http://www.w3schools.com/cssref/css_colors_legal.asp)
  # and [Mozilla's Color Reference](
  # https://developer.mozilla.org/en-US/docs/Web/CSS/color_value)
  # and Doug Crockford's [interactive named colors](
  # http://www.crockford.com/wrrrld/color.html) page
  # as well as the [future CSS4](http://dev.w3.org/csswg/css-color/) spec.
  #
  # The strings can be may forms:
  # * Names: [140 color case-insensitive names](
  #   http://en.wikipedia.org/wiki/Web_colors#HTML_color_names) like
  #   Red, Green, CadetBlue, and so on.
  # * Hex, short and long form: #0f0, #ff10a0
  # * RGB: rgb(255, 0, 0), rgba(255, 0, 0, 0.5)
  # * HSL: hsl(120, 100%, 50%), hsla(120, 100%, 50%, 0.8)

  # Convert 4 r,g,b,a ints in [0-255] to a css color string.
  # Alpha "a" is int in [0-255], not the "other alpha" float in 0-1
  rgbaString: (r, g, b, a=255) ->
    a = a/255; a4 = a.toPrecision(4)
    if a is 1 then "rgb(#{r},#{g},#{b})" else "rgba(#{r},#{g},#{b},#{a4})"

  # Convert 3 ints, h in [0-360], s,l in [0-100]% to a css color string.
  # Alpha "a" is int in [0-255].
  #
  # Note h=0 and h=360 are the same, use h in 0-359 for unique colors.
  hslString: (h, s, l, a=255) ->
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

  # This is a hybrid string and generally our default.  It returns:
  #
  # * rgbaString if a not 255 (i.e. not opaque)
  # * hexString otherwise
  # * with the hexShortString if appropriate
  triString: (r, g, b, a=255) ->
    if a is 255 then @hexString(r, g, b, true) else @rgbaString(r, g, b, a)

# ### CSS String Conversions

  # Return 4 element array given any legal CSS string color
  # [legal CSS string color](
  # http://www.w3schools.com/cssref/css_colors_legal.asp)
  #
  # Legal strings vary widely: CadetBlue, #0f0, rgb(255,0,0), hsl(120,100%,50%)
  #
  # Note: The browser speaks for itself: we simply set a 1x1 canvas fillStyle
  # to the string and create a pixel, returning the r,g,b,a Typed Array
  # Odd results if string is not recognized by browser.

  # The shared 1x1 canvas 2D context.
  sharedCtx1x1: u.createCtx 1, 1 # share across calls.
  # Convert css string to typed array.
  # If you need a JavaScript Array, use uint8sToRgba
  stringToUint8s: (string) -> # string = string.toLowerCase()?
    @sharedCtx1x1.fillStyle = string
    @sharedCtx1x1.fillRect 0, 0, 1, 1
    @sharedCtx1x1.getImageData(0, 0, 1, 1).data

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
    @sharedUint8s.set [r, g, b, a]
    @sharedPixel[0]

  # Convert a pixel to Uint8s via the shared typed views.
  # sharedOK = true returns the sharedUint8s, useful
  # for one-time computations like finding the pixel r,g,b,a values.
  # Default is to clone the sharedUint8s.
  pixelToUint8s: (pixel, sharedOK = false) ->
    @sharedPixel[0] = pixel
    if sharedOK then @sharedUint8s else new Uint8ClampedArray @sharedUint8s

# ### Color Conversion and Scaling Functions.

  # Return rgb array with 3 random ints in 0-255.
  # Convert to random cssString or pixel via functions above.
  randomRgb: -> (u.randomInt(256) for i in [0..2])
  # Return random gray color, with intensities in [min,max).
  randomGrayRgb: (min = 0, max = 256) ->
    i = u.randomInt2 min, max
    [i, i, i]

  # Convert Uint8s to Array (avoid "new Array", better JS translation.)
  # Useful after pixelToUint8s, stringToUint8s, hslToRgb
  uint8sToRgba: (uint8s) -> Array uint8s...

  # Return the gray/intensity float value for a given r,g,b color
  # Use Math.round to convert to 0-255 int for gray color value.
  # [Good post on image filters](
  # http://www.html5rocks.com/en/tutorials/canvas/imagefilters/)
  rgbIntensity: (r, g, b) -> 0.2126*r + 0.7152*g + 0.0722*b


  # Convert h,s,l to r,g,b Typed subarray via stringToUint8s
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

  # Scale a data value to an rgb color.
  # value is in [min max], rgb's are two colors.
  # This can make simple, two color, gradient color maps.
  # See ColorMap.scaleColor for related scaling method and
  # ColorMap.gradientUint8Array for complex, MatLab-like, gradients.
  rgbLerp: (value, min, max, rgb1, rgb0 = [0,0,0]) ->
    scale = u.lerpScale value, min, max #(value - min)/(max - min)
    (Math.round(u.lerp(rgb0[i], rgb1[i], scale)) for i in [0..2])

# ### Typed Color

  # A typed color is a typed array with r,g,b,a in 0-255 and optional
  # css string. As usual, a is in 0-255, *not* in 0-1 as in some color formats.
  #
  # Return a 4 element Uint8ClampedArray, with two properties:
  #
  # * pixelArray: A single element Uint32Array view on the Uint8ClampedArray
  # * string: an optional, lazy evaluated, css color string.
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
    # creates a TypedColorProto with an Uint proto, which is in turn
    # set to the proto of the typedColor returned value.  Whew!
    # This allows TypedArrays to have prototype properties,
    # including Object.defineProperties without enlarging them.
    #
    # Experimental: The map & index are for possible colormap use.
    # If r is not a number but a typed array, use it for the typedColor.
    typedColor = (r, g, b, a=255, map, index) ->
      if map # assume Uint8ClampedArray rgba array
        ua = map.subarray index*4, index*4 + 4
        ua.set [r,g,b,a]
        # ua.pixelArray = new Uint32Array(map.buffer, index*4, 1)
      else
        ua = if g then new Uint8ClampedArray([r,g,b,a]) else r
        # ua = if r.buffer then r else new Uint8ClampedArray([r,g,b,a])
      ua.pixelArray = new Uint32Array(ua.buffer, ua.byteOffset, 1)
      # lazy evaluation will set the css triString for this typed array.
      #
      #     ua.string = Color.triString(r, g, b, a)
      #
      # do not set the ua.string directly, will get typed values out of sync.

      # Make me an instance of TypedColorProto
      ua.__proto__ = TypedColorProto
      ua
    TypedColorProto = {
      # Set TypedColorProto proto to be Uint8ClampedArray's prototype
      __proto__: Uint8ClampedArray.prototype
      # Set the typed array; no need for getColor, it *is* the typed Uint8 array
      setColor: (r,g,b,a=255) ->
        @string = null if @string # will be lazy evaluated via getString.
        @[0]=r; @[1]=g; @[2]=b; @[3]=a
        @
      # Set the pixel view, changing the shared array (Uint8) view too
      setPixel: (pixel)->
        @string = null if @string # will be lazy evaluated via getString.
        @pixelArray[0]=pixel
      # Get the pixel value
      getPixel: -> @pixelArray[0]
      # Set both Typed Arrays to equivalent pixel/rgba values of the css string.
      #
      # Does *not* set the chached @string, it will be lazily evaluated to its
      # triString. This lets the typedColor remain small without the
      # color string until required by its getter.
      #
      # Note if you set string to "red" or "rgb(255,0,0)", the resulting
      # css string (triString) value will return the triString #f00 value.
      setString: (string) ->
        @setColor(Color.stringToUint8s(string)...)
      # Return the triString for this typedColor, cached in the @string value
      getString: (string) ->
        @string = Color.triString(@...) unless @string
        @string
    }
    # Sugar for converting getter/setters into properties.
    # Somewhat slower than getter/setter functions.
    # Frequent rgba property setter very poor performance due to GC overhead.
    # These are in TypedColorProto, not in the typedColor,
    # thus shared and take no space in the color itself.
    Object.defineProperties TypedColorProto,
    # pixel: get/set typedColor.pixelArray[0] via pixel property
      "pixel":
        get: -> @pixelArray[0]
        set: (val) -> @setPixel(val)
        enumerable: true # make visible in stack trace, remove after debugging
    # uints: set Uint8 values via JavaScript or Typed Array. Getter not needed.
      "uints":
        get: -> @ #.. not needed, already array
        set: (val) -> @setColor(val...) # beware! array GC slows this down.
        enumerable: true # make visible in stack trace, remove after debugging
    # css: get/set typedColor.str via @string property. Updates TypedArrays.
      "css":
        get: -> @getString()
        set: (val) -> @setString(val)
        enumerable: true # make visible in stack trace, remove after debugging
    # str: Legacy usage, identical to css getter property, will remove asap
      "str":
        get: -> @getString()
        enumerable: true # make visible in stack trace, remove after debugging
    typedColor

# ### Color Types
#
# We support these color types: css, pixel, uint8s, typed

  # Return the color type of a given color, null if not a color.
  # null useful for testing if color *is* a color.
  colorType: (color) ->
    if u.isString color  then return "css"
    if u.isInteger color then return "pixel"
    if color.pixelArray  then return "typed"
    null
  # Return new color of the given type, given an r,g,b,(a) array,
  # where a defaults to opaque (255).
  # The array can be a JavaScript Array, a TypedArray, or a TypedColor.
  # Use randomRgb & randomGrayRgb to create random typed colors.
  arrayToColor: (array, type) ->
    switch type
      when "css"   then return Color.triString array...
      when "pixel" then return Color.rgbaToPixel array...
      when "typed"
        return if array.buffer then @typedColor array else @typedColor array...
    u.error "arrayToColor: incorrect type: #{type}"
  # Return array (either typed or Array) representing the color.
  colorToArray: (color) ->
    type = @colorType(color)
    switch type
      when "css"   then return Color.stringToUint8s color
      when "pixel" then return Color.pixelToUint8s color
      when "typed" then return color # already a (typed) array
    u.error "colorToArray: bad color: #{color}"
  # With arrayToColor & colorToArray we can convert between all color types.
  # Given a color and a type, convert color to that type.
  convertColor: (color, type) ->
    # Return color if color is already of type.
    return color if @colorType(color) is type
    @arrayToColor(@colorToArray(color), type)

};
Color.initSharedPixel() # Initialize the shared buffer pixel/rgb view

# Here are the 140 case insensitive legal color names (the X11 set)
# To include them in your model, use:
#
#     namedColorString = "AliceBlue AntiqueWhite Aqua Aquamarine Azure Beige Bisque Black BlanchedAlmond Blue BlueViolet Brown BurlyWood CadetBlue Chartreuse Chocolate Coral CornflowerBlue Cornsilk Crimson Cyan DarkBlue DarkCyan DarkGoldenRod DarkGray DarkGreen DarkKhaki DarkMagenta DarkOliveGreen DarkOrange DarkOrchid DarkRed DarkSalmon DarkSeaGreen DarkSlateBlue DarkSlateGray DarkTurquoise DarkViolet DeepPink DeepSkyBlue DimGray DodgerBlue FireBrick FloralWhite ForestGreen Fuchsia Gainsboro GhostWhite Gold GoldenRod Gray Green GreenYellow HoneyDew HotPink IndianRed Indigo Ivory Khaki Lavender LavenderBlush LawnGreen LemonChiffon LightBlue LightCoral LightCyan LightGoldenRodYellow LightGray LightGreen LightPink LightSalmon LightSeaGreen LightSkyBlue LightSlateGray LightSteelBlue LightYellow Lime LimeGreen Linen Magenta Maroon MediumAquaMarine MediumBlue MediumOrchid MediumPurple MediumSeaGreen MediumSlateBlue MediumSpringGreen MediumTurquoise MediumVioletRed MidnightBlue MintCream MistyRose Moccasin NavajoWhite Navy OldLace Olive OliveDrab Orange OrangeRed Orchid PaleGoldenRod PaleGreen PaleTurquoise PaleVioletRed PapayaWhip PeachPuff Peru Pink Plum PowderBlue Purple Red RosyBrown RoyalBlue SaddleBrown Salmon SandyBrown SeaGreen SeaShell Sienna Silver SkyBlue SlateBlue SlateGray Snow SpringGreen SteelBlue Tan Teal Thistle Tomato Turquoise Violet Wheat White WhiteSmoke Yellow YellowGreen"
#     namedColors = namedColorString.split(" ")
