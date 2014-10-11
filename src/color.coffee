ABM.Color = Color = {
  # Create color object from r,g,b,a
  # Note a between 0-1, not 0-255
  # The object contains many properties relating to
  # the r,g,b,a color:
  #   r, g, b, h, s, v: color integers, 0-255 based
  #   a, a255: alpha, a float in 0-1, a255 integer in 0-255
  #   rgb, hsb: array forms of the two colors
  #   intensity: the gray value for the rgb color
  #   rgba, pixel: typed array values.
  #   rgbString, hexColor: two html/css color formats
  colorObject: (r, g, b, a=1) ->
    o = {r,g,b,a}
    o.a255 = Math.round(a*255)
    o.rgb = [r, g, b]
    o.hsv = @rgbToHsv r, g, b
    [o.h, o.s, o.v] = o.hsv
    # o.rgba = new Uint8ClampedArray([r, g, b, o.a255])
    # o.pixel = new Uint32Array(o.rgba.buffer)[0]
    # {o.pixel, o.rgba} = typedArrayColor r, g, b, a255
    {pixel, rgba} = @typedArrayColor r, g, b, o.a255
    [o.pixel, o.rgba] = [pixel, rgba]
    o.rgbString = @rgbString r, g, b, a
    o.hexColor = @hexColor r, g, b
    o.intensity = @rgbIntensity r, g, b
    o.temp = @rgbDistance 0,0,0, r,g,b
    o

  # Color utilities.

  # Convert 3 or 4 ints to a html/css color string
  rgbString: (r, g, b, a=1) ->
    throw new Error "alpha > 1" if a > 1 # a: 0-1 not 0-255
    if a is 1 then "rgb(#{r},#{g},#{b})" else "rgba(#{r},#{g},#{b},#{a})"

  # Return the gray/intensity value for a given r,g,b color
  rgbIntensity: (r, g, b) -> 0.2126*r + 0.7152*g + 0.0722*b

  # Return a web/html/css hex color string for an r,g,b color
  hexColor: (r, g, b) ->
    "#" + (0x1000000 | (b | g << 8 | r << 16)).toString(16).slice(-6)

  # Return 2 typed array colors: a single Uint32 pixel, correct endian format,
  # and a 4 Uint8Array, r,g,b,a255 (i.e. a int in 0-255)
  typedArrayColor: (r, g, b, a=255) ->
    rgba = new Uint8ClampedArray([r, g, b, a])
    pixel = new Uint32Array(rgba.buffer)[0]
    {pixel, rgba}

  # Convert rgb color to hsb/hsv color array
  rgbToHsv: (r, g, b) ->
    r=r/255; g=g/255; b=b/255
    max = Math.max(r,g,b); min = Math.min(r,g,b); v = max
    h = 0; d = max-min; s = if max is 0 then 0 else d/max
    if max isnt min then switch max
      when r then h = (g - b) / d + (if g < b then 6 else 0)
      when g then h = (b - r) / d + 2
      when b then h = (r - g) / d + 4
    [Math.round(255*h/6), Math.round(255*s), Math.round(255*v)]

  # Convert hsv back to rgb
  hsvToRgb: (h, s, v) ->
    h=h/255; s=s/255; v=v/255; i = Math.floor(h*6)
    f = h * 6 - i;        p = v * (1 - s)
    q = v * (1 - f * s);  t = v * (1 - (1 - f) * s)
    switch(i % 6)
      when 0 then r = v; g = t; b = p
      when 1 then r = q; g = v; b = p
      when 2 then r = p; g = v; b = t
      when 3 then r = p; g = q; b = v
      when 4 then r = t; g = p; b = v
      when 5 then r = v; g = p; b = q
    [Math.round(r*255), Math.round(g*255), Math.round(b*255)] # floor??

  # Return a distance metric between two colors.
  # http://www.compuphase.com/cmetric.htm
  rgbDistance: (r1, g1, b1, r2, g2, b2) ->
    rMean = Math.round (r1 + r2) / 2
    [dr, dg, db] = [r1 - r2, g1 - g2, b1 - b2]
    Math.sqrt (((512+rMean)*dr*dr)>>8) + (4*dg*dg) + (((767-rMean)*db*db)>>8)

  # A colormap is an array of ColorObjects which have two additional
  # properties: map: the colormap and ix: the color's index w/in map
  ColorMap: class ColorMap extends Array
    # A colormap is an array of Color objects. Each ColorObject has
    # two new properties: ix, the array index, and map, the colormap
    # The ctor takes an array of [r,g,b] arrays. See factories above.
    constructor: (rgbArray) ->
      super(0)
      for c, i in rgbArray
        @push Color.colorObject c... # use splats
        @[i].ix = i
        @[i].map = @

    # The Array.sort, augmented by updating color.ix to correspond
    # to the new place in the array
    sort: (f) ->
      super f
      color.ix = i for color, i in @ # c: color, i
      @

    # Sugar for sorting by color.key, mainly intensity.
    sortBy: (key, ascenting=true) ->
      compare = (a, b) ->
        if ascenting then a[key]-b[key] else b[key]-a[key]
      @sort compare

    # Find an rgb color in the map, return -1 if not found
    findRGB: (r, g, b) ->
      for color, i in @
        return i if color.r is r and color.g is g and color.b is b
      -1

    # Find a color with the given key/value, -1 if not found
    find: (key, value) ->
      for color, i in @
        return color if color[key] is value
      -1

    # Return an random color or index in a map.
    randomColor: -> @[@randomIndex()]
    # Standalone: Math.floor(Math.random() * @length)
    randomIndex: -> u.randomInt @length

    # Find the color closest to this rgb color, based on intensity
    # sum of squares, and closestHSV
    # http://en.wikipedia.org/wiki/Color_difference
    closestRGB: (r, g, b) ->
      minDist = Infinity
      ixMin = 0
      for color, i in @
        d = Color.rgbDistance color.rgb..., r, g, b
        if d < minDist
          minDist = d
          ixMin = i
      @[ixMin]

  # Utilities for creating color maps
  # https://github.com/bpostlethwaite/colormap

  # Create a gray map of gray values (gray: r=g=b)
  # The optional size argument is the size of the map for
  # maps that are not all 256 grays.
  intensityArray: (size = 256) ->
    (Math.round(i*255/(size-1)) for i in [0...size])
  grayColorMap: (size = 256) ->
    new ColorMap ([i,i,i] for i in @intensityArray(size))

  # Create a colormap by rgb values. R, G, B can be either a number,
  # the number of steps beteen 0-255, or an array of values to use
  # for the color.  Ex: R = 3, corresponds to [0, 128, 255]
  # The resulting map permutes the R, G, V values.  Thus if
  # R=G=B=4, the resulting map has 4*4*4=64 colors.
  rgbColorArray: (R,G=R,B=R) ->
    R = (Math.round(i*255/(R-1)) for i in [0...R]) if typeof R is "number"
    G = (Math.round(i*255/(G-1)) for i in [0...G]) if typeof G is "number"
    B = (Math.round(i*255/(B-1)) for i in [0...B]) if typeof B is "number"
    array=[]; ((array.push [r,g,b] for b in B) for g in G) for r in R
    array
  rgbColorMap: (R,G=R,B=R) ->
    new ColorMap @rgbColorArray(R, G, B)

  # Create an hsb map with n hues, with constant saturation
  # and brightness.
  hsvColorArray: (nHues=256, s=255, b=255) ->
    (Color.hsvToRgb(i*255/(nHues-1), s, b) for i in [0...nHues])
  hsvColorMap: (nHues=256, s=255, b=255) ->
    new ColorMap @hsvColorArray(nHues, s, b)

  # Use the canvas gradient feature to create nColors.
  # This is a really sophisticated technique, see:
  #  https://developer.mozilla.org/en-US/docs/Web/CSS/linear-gradient
  #  http://www.colorzilla.com/gradient-editor/
  #  https://github.com/bpostlethwaite/colormap
  gradientColorArray: (nColors, stops, locs) ->
    locs = (i/(stops.length-1) for i in [0...stops.length]) if not locs?
    # util: ctx = u.createCtx nColors, 1
    can = document.createElement "canvas"
    can.width = nColors; can.height = 1
    ctx = can.getContext "2d"
    grad = ctx.createLinearGradient 0, 0, nColors, 0
    for i in [0...stops.length]
      grad.addColorStop locs[i], Color.rgbString(stops[i]...)
    ctx.fillStyle = grad
    ctx.fillRect 0, 0, nColors, 1
    # util: id = u.ctxToImageData(ctx).data
    id = (ctx.getImageData 0, 0, nColors, 1).data
    ([id[i], id[i+1], id[i+2]] for i in [0...id.length] by 4)
  gradientColorMap: (nColors, stops, locs) ->
    new ColorMap @gradientColorArray(nColors, stops, locs)

  # Create a color map via the 140 html standard colors.  We use a minimal
  # string format: "XXXXXXColorName", the 6 hex digits followed by the name.
  # Ex: "000000Black" or "FF0000Red".
  # The input is a single string of space separated name specs.
  nameColorMap: (colorsString) ->
    colorStrings = colorsString.split " "
    names = (colorString.slice(6) for colorString in colorStrings)
    hexes = (colorString.slice(0,6) for colorString in colorStrings)
    toint = (str, start) -> parseInt(str.slice(start,start+2), 16)
    rgbs = ( [ toint(h,0), toint(h,2), toint(h,4) ] for h in hexes)
    map = new ColorMap rgbs
    for c, i in map
      c.name = names[i]
      map[c.name] = c
      map[c.name.toLowerCase()] = c
    map

  # Create a map with a random set of colors.
  # Sometimes useful to sort by intensity afterwards.
  randomColorMap: (nColors) ->
    rand255 = -> Math.floor(Math.random() * 256) # util.randomInt
    new ColorMap ([rand255(), rand255(), rand255()] for i in [0...nColors])

};
