  # This module contains three color sections:
  #
  # * Core color primitive functions
  # * A color object
  # * A color map class and several colormap "factories"
  #
  # Colors in HTML/CSS are strings, see [legal CSS string colors](
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
  #
  # In addition, numeric Typed Arrays are used in canvas's [ImageData pixels](
  # https://developer.mozilla.org/en-US/docs/Web/API/ImageData)
  # and WebGL colors (4 rgba floats in 0-1)
  #
  # There are many other representations, such as floats in 0-1
  # and odd mixtures of values, some in degrees, some in percentages.

window.c = Color = {
  # ### Core Color Functions

  # Convert 3 r,g,b ints in [0-255] to a css color string.
  # Alpha "a" is opacity, float in [0-1]
  rgbString: (r, g, b, a=1) ->
    throw new Error "alpha > 1" if a > 1 # a: 0-1 not 0-255
    if a is 1 then "rgb(#{r},#{g},#{b})" else "rgba(#{r},#{g},#{b},#{a})"

  # Convert 3 ints, h in [0-360], s,l in [0-100]% to a css color string.
  # Alpha "a" is opacity, float in [0-1]. Some browsers will allow floats
  # in 0-1 for s,l rather than int % values in 0-100.
  #
  # Note h=0 and h=360 are the same, you typically limit yourself to h in 0-359.
  # The browser clamps the h,s,l values to legal values.
  hslString: (h, s, l, a=1) ->
    throw new Error "alpha > 1" if a > 1 # a: 0-1 not 0-255
    if a is 1 then "hsl(#{h},#{s}%,#{l}%)" else "hsla(#{h},#{s}%,#{l}%,#{a})"

  # Return the gray/intensity float value for a given r,g,b color
  # Round for 0-255 int for gray color value.
  # [Good post on image filters](
  # http://www.html5rocks.com/en/tutorials/canvas/imagefilters/)
  rgbIntensity: (r, g, b) -> 0.2126*r + 0.7152*g + 0.0722*b

  # Return a web/html/css hex color string for an r,g,b color.
  # Identical color will be drawn as if using rgbString above
  # but without an alpha capability.
  rgbToHex: (r, g, b) ->
    "#" + (0x1000000 | (b | g << 8 | r << 16)).toString(16).slice(-6)

  # Return a single Uint32 pixel, correct endian format. If arrayToo
  # also return a 4 Uint8Array, r,g,b,a255, each a Uint8 in 0-255
  rgbToPixel: (r, g, b, a255=255, arrayToo = false) ->
    rgba255 = new Uint8ClampedArray([r, g, b, a255])
    pixel = new Uint32Array(rgba255.buffer)[0]
    if arrayToo then [pixel, rgba255] else pixel
  # Convert a pixel to a typed Uint8 r,g,b,a255 array
  pixelToRgb: (pixel) ->
    pixelArray = new Uint32Array([pixel])
    new Uint8ClampedArray(pixelArray.buffer)

  # Return an RGB array given any legal CSS string color
  # [legal CSS string color](
  # http://www.w3schools.com/cssref/css_colors_legal.asp)
  # , null otherwise.
  #
  # Legal strings vary widely: CadetBlue, #0f0, rgb(255,0,0), hsl(120,100%,50%)
  #
  # (The rgba/hsla forms ok too, but we don't return the a in 0-255 int value)
  #
  # Note: The browser speaks for itself: we simply set a 1x1 canvas fillStyle
  # to the string and create a pixel, returning the r,g,b values.
  #
  # Warning: r=g=b=0 can indicate an illegal string.  We test
  # for a few obvious cases but beware of unexpected [0,0,0] results.
  sharedCtx1x1: u.createCtx 1, 1 # share across calls.
  stringToRgb: (string) ->
    string = string.toLowerCase()
    @sharedCtx1x1.clearRect 0, 0, 1, 1
    @sharedCtx1x1.fillStyle = string
    @sharedCtx1x1.fillRect 0, 0, 1, 1
    string = string.replace(/\ */g, '') # "\ " a coffee disambiguation problem
    [r, g, b, a] = @sharedCtx1x1.getImageData(0, 0, 1, 1).data
    # console.log string, [r, g, b, a]
    return [r, g, b] if (r+g+b isnt 0) or
      (string in ["#000","#000000","transparent","black"]) or
      (string.match(/rgba{0,1}\(0,0,0/)) or
      (string.match(/hsla{0,1}\([^,]*,[^,]*,0%/))
    null

  # RGB <> HSL (Hue, Saturation, Lightness) conversions.
  #
  # r,g,b are ints in [0-255], i.e. 3 unsigned bytes of a pixel.
  # h int in [0-360] degrees; s,v ints [0-100] percents; (h=0 same as h=360)
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

  # Convert float in 0-1 to int in 0-max
  roundToInt: (float, max=255) ->
    console.log "roundToInt: float #{float}, max #{max}" unless 0 <= float <= 1
    int = Math.round(max*float)
    console.log "roundToInt: int #{int}, max #{max}" unless 0 <= int <= max
    u.clamp int, 0, max

  # Convert r, g, b to [h, s, l] array.
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
    [@roundToInt(h/6, 360), @roundToInt(s, 100), @roundToInt(l, 100)]

  # Convert h, s, l to r, g, b by use of stringToRgb.
  hslToRgb: (h, s, l) ->
    str = @hslString(h, s, l)
    @stringToRgb str


  # Return array of 3 random values in 0-255.
  randomRgbColor: -> (u.randomInt(256) for i in [0..2])

  # Return a [distance metric](
  # http://www.compuphase.com/cmetric.htm) between two colors.
  # Max distance is roughly 765 (3*255), between black & white.
  rgbDistance: (r1, g1, b1, r2, g2, b2) ->
    rMean = Math.round( (r1 + r2) / 2 )
    [dr, dg, db] = [r1 - r2, g1 - g2, b1 - b2]
    Math.sqrt (((512+rMean)*dr*dr)>>8) + (4*dg*dg) + (((767-rMean)*db*db)>>8)

  # A very crude way to scale a data value to an rgb color.
  # value is in [min max], rgb's are two color.
  # See ColorMap.scaleColor for preferred method
  rgbLerp: (value, min, max, rgb1, rgb0 = [0,0,0]) ->
    scale = u.lerpScale value, min, max #(value - min)/(max - min)
    (Math.round(u.lerp(rgb0[i], rgb1[i], scale))) for i in [0..2]

  # ### Color Object

  # Create color object from r,g,b,a
  # Note a between 0-1, not 0-255
  #
  # The object contains many properties relating to
  # the r,g,b,a color:
  #
  # * r, g, b, h, s, l: color integers, see above
  # * a, a255: alpha, a float in 0-1, a255 integer in 0-255
  # * intensity: the float computed gray value for the rgb color
  # * rgba255, pixel: typed array values.
  # * rgbString, hexString: two html/css color formats


  # Options: Control the number of color features in colorObject.
  #
  # Example: To remove intensity, call options() for the set of
  # default options, and modify as you'd like
  #
  # If all options false, only r,g,b,a remain.
  options: ->
    hsl: true         # store individual calculated h,s,l values
    pixel: true       # store Uint32 pixel
    intensity: true   # store float intensity calculated from r,g,b
    rgbString: true   # store css rgb/rgba string
    hexString: true   # store css hex (r,g,b) string

  # Create a colorObject with all the color types supplied by the primitives.
  # Use the options object if you want to eliminate any of the color features.
  # Call colorObject with hslToRgb(h,s,l)... if you are working in hue space.
  colorObject: (r, g, b, a=1, opt=@options()) ->
    o = {r,g,b,a}
    [o.h, o.s, o.l] = @rgbToHsl r, g, b if o.hsl
    if opt.pixel
      o.a255 = Math.round(a*255)
      o.pixel = @rgbToPixel r, g, b, o.a255
    o.intensity = @rgbIntensity r, g, b if opt.intensity
    o.rgbString = @rgbString r, g, b, a if opt.rgbString
    o.hexString = @rgbToHex r, g, b if opt.hexString
    o
  # Mainly legacy: return an rgb/rgba array.  Beware GC overhead!
  colorObjToRgb: (o) ->
    if o.a is 1 then [o.r, o.g, o.b] else  [o.r, o.g, o.b, o.a]

  randomColorObject: (a=1, opt=@options()) ->
    # randomColor = @randomColor()
    @colorObject @randomRgbColor()..., a, opt

  # ### Color Maps

  # A colormap is an array of ColorObjects. Maps are extremely useful:
  #
  # * Performance: Maps are created once, reducing the calls to primitives
  #   whenever a color is changed.
  # * Space Effeciency: They *vastly* reduce the number of color objects used.
  # * Data: They provide a MatLab/NumPy "color as data" feature.
  #   Ex: "Heat" may be mapped to a gradient from green to red.

  # A data colormap is designed for the model/view interface.
  # A model is a time varying set of data values.
  # A view presents these values to the user visually.
  #
  # The data colormap lets the model compute an index into an array
  # of colors for the view to use.
  DataColorMap: class DataColorMap extends Array
    # A data colormap is an array of any of the forms of color
    # discussed above: css string, pixel, rgba255 typed array.
    #
    # The ctor takes an array sorted so that model data values scale
    # into the array's indices: [0, length-1], along with a function
    # to convert the array items into a valid color.
    #
    # Example: the array can be the ints from 0-255 and the function
    # converts them into gray colors such as css strings or pixels.
    # The default function is the identity, and the input array
    # valid colors.
    constructor: (array, aToColor=(a)->a) ->
      super(0)
      @push aToColor(a) for a in array

    # Return an random color or index in a map.
    randomIndex: -> u.randomInt @length
    randomColor: -> @[@randomIndex()]

    # Return the map index proportional to the value between min, max.
    # This is a linear interpolation based on the map indices.
    # The optional minColor, maxColor args are for using a subset of the map.
    scaleIndex: (number, min, max, minColor = 0, maxColor = @length-1) ->
      scale = u.lerpScale number, min, max # (number-min)/(max-min)
      Math.round(u.lerp minColor, maxColor, scale)
    # Same but return color at the computed index
    scaleColor: (number, min, max, minColor = 0, maxColor = @length-1) ->
      @[@scaleIndex(number, min, max, minColor, maxColor)]


  # The more general colormap, mainly for designing and minipulating
  # colors.
  ColorMap: class ColorMap extends Array
    # A colormap is an array of Color objects. Each ColorObject has
    # two additional properties: ix, the array index, and map, the colormap.
    # This allows scaling, adding/subtracting, quick equality checking and
    # other arithmetic operations.  The indices are another color-as-data
    # feature.
    #
    # The ctor takes an array of [r,g,b] arrays. See factories below
    # for help making the basic colormap types.
    constructor: (rgbArray, @options = Color.options(), @dupsOK = false) ->
      # Note we keep a copy of the color options argument.
      # We also allow dups if dupsOK true.  Default is false.
      # Dups would be OK when keeping an index by color name as well
      # as the default index by rgb string. There are 2 dups in the
      # legal 140 named colors.
      super(0)
      # We also keep an index for rapid lookup of a color within the map.
      # It will always have the rgb string for the color.  It can also have
      # values such as the color name (green) or other string values.
      @index = {}
      @addColor rgb... for rgb, i in rgbArray


    # Append a color to the the map if it isn't already
    # in the map unless dupsOK.  Keep an index by rgb string.
    # Return the color object.
    addColor: (r, g, b, a=1)  ->
      rgbString = Color.rgbString r, g, b, a
      if not @dupsOK
        color = @index[ rgbString ]
        console.log("dup color", color) if color
      if not color
        color = Color.colorObject r, g, b, a, @options
        color.ix = @length
        color.map = @
        @index[rgbString] = color
        @push color
      color

    # The Array.sort, augmented by updating color.ix to correspond
    # to the new place in the array
    sort: (f) ->
      super f
      color.ix = i for color, i in @
      @

    # Sugar for sorting by color.key, mainly intensity.
    sortBy: (key, ascenting=true) ->
      compare = (a, b) ->
        if ascenting then a[key]-b[key] else b[key]-a[key]
      @sort compare

    # Find an rgb color in the map, return undefined if not found
    findRgb: (r, g, b, a=1) ->
      @index[ Color.rgbString(r, g, b, a) ]

    # Find first color with the given key/value, undefined if not found
    findKey: (key, value) ->
      for color, i in @
        return color if color[key] is value
      undefined

    # Return an random color or index in a map.
    randomIndex: -> u.randomInt @length
    randomColor: -> @[@randomIndex()]

    # Return the map color proportional to the value between min, max.
    # This is a linear interpolation based on the map indices.
    # The optional minColor, maxColor args are for using a subset of the map.
    scaleColor: (number, min, max, minColor = 0, maxColor = @length-1) ->
      scale = u.lerpScale number, min, max # (number-min)/(max-min)
      # minColor = minColor.ix if minColor.ix?
      # maxColor = maxColor.ix if maxColor.ix?
      index = Math.round(u.lerp minColor, maxColor, scale)
      @[index]

    # Find the color closest to this color, using Color.rgbDistance.
    findClosest: (r, g, b) ->
      return color if ( color = @findRgb(r, g, b) )
      minDist = Infinity
      ixMin = 0
      for color, i in @
        d = Color.rgbDistance color.r, color.g, color.b, r, g, b
        if d < minDist
          minDist = d
          ixMin = i
      @[ixMin]

  # Utilities for creating color maps, inspired [by this repo](
  # https://github.com/bpostlethwaite/colormap).
  # Omit the options and dupsOK arguments for defaults.

  # Create a gray map of gray values (gray: r=g=b)
  # The optional size argument is the size of the map for
  # maps that are not all 256 grays.
  grayValueArray: (size = 256) ->
    u.error "Color: gray value > 256" if size > 256
    u.aIntRamp 0, 255, size
  grayColorArray: (size = 256) ->
    ([i,i,i] for i in @grayValueArray(size))
  grayColorMap: (size = 256, options) ->
    new ColorMap @grayColorArray(size), options, false

  # Utility to permute 3 arrays.
  #
  # * If any arg is array, no change made.
  # * If any arg is 1, replace with [max].
  # * If any arg is n>1, replace with u.aIntRamp(0,max,n).
  #
  # Resulting array is an array of arrays of len 3 permuting A1, A2, A3
  # Used by rgbColorArray and hslColorArray.
  permuteColors: (isRGB, A1, A2=A1, A3=A2) ->
    max = if isRGB then [255,255,255] else [359,100,100]
    [A1, A2, A3] = for A, i in [A1, A2, A3] # multi-line comprehension
      if typeof A is "number"
        if A is 1
          [max[i]]
        else
          u.aIntRamp(0, max[i], A)
      else
        A
    array= []
    ((array.push [a1,a2,a3] for a1 in A1) for a2 in A2) for a3 in A3
    # console.log [A1,A2,A3], array
    array

  # Create a colormap by rgb values. R, G, B can be either a number,
  # the number of steps beteen 0-255, or an array of values to use
  # for the color.  Ex: R = 3, corresponds to [0, 128, 255]
  # The resulting map permutes the R, G, V values.  Thus if
  # R=G=B=4, the resulting map has 4*4*4=64 colors.

  rgbColorArray: (R, G=R, B=R) -> @permuteColors(true, R, G, B)
  rgbColorMap: (R, G=R, B=R, options, dupsOK) ->
    map = new ColorMap @rgbColorArray(R, G, B), options, dupsOK

  # Create an hsl map, inputs similar to above.  Convert the
  # HSL values to RGB, default to hue ramp.
  hslColorArray: (H, S=1, L=1) -> @permuteColors(false, H, S, L)
  hslColorMap: (H, S=1, L=1, options, dupsOK) ->
    hslArray = @hslColorArray(H, S, L)
    # console.log "hslArray: ", hslArray
    rgbArray = (@hslToRgb a... for a in hslArray) # @hslColorArray(H, S, L))
    # console.log "rgbArray: ", rgbArray
    new ColorMap rgbArray, options, dupsOK

  # Use the canvas gradient feature to create nColors.
  # This is a really powerful technique, see:
  #
  # * [Mozilla Gradient Doc](
  #   https://developer.mozilla.org/en-US/docs/Web/CSS/linear-gradient)
  # * [Colorzilla Gradient Editor](
  #   http://www.colorzilla.com/gradient-editor/)
  # * [GitHub ColorMap Project](
  #   https://github.com/bpostlethwaite/colormap)
  gradientColorArray: (nColors, stops, locs) ->
    locs = (i/(stops.length-1) for i in [0...stops.length]) if not locs?
    ctx = u.createCtx nColors, 1
    grad = ctx.createLinearGradient 0, 0, nColors, 0
    for i in [0...stops.length]
      grad.addColorStop locs[i], @rgbString(stops[i]...)
    ctx.fillStyle = grad
    ctx.fillRect 0, 0, nColors, 1
    id = u.ctxToImageData(ctx).data
    ([id[i], id[i+1], id[i+2]] for i in [0...id.length] by 4)
  gradientColorMap: (nColors, stops, locs, options, dupsOK) ->
    new ColorMap @gradientColorArray(nColors, stops, locs), options, dupsOK

  # Create a color map via the 140 html standard colors.
  # The input is an object of name: [r,g,b] pairs
  nameColorMap: (colorPairs, options, dupsOK=true) ->
    rgbs = ( v for k, v of colorPairs )
    names = ( k for k, v of colorPairs )
    map = new ColorMap rgbs, options, dupsOK
    for color, i in map
      name = names[i]
      # color.name = name # bad idea, named colors can have duplicates
      map.index[name] = color
      # map.index[name.toLowerCase()] = color
    map

  # Create a map with a random set of colors.
  # Sometimes useful to sort by intensity afterwards.
  randomColorArray: (nColors) ->
    (@randomRgbColor() for i in [0...nColors])
  randomColorMap: (nColors, options, dupsOK) ->
    new ColorMap @randomColorArray(nColors), options, dupsOK

};
