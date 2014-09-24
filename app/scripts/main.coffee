shuffle = (array) ->
    counter = array.length

    # While there are elements in the array
    while counter > 0
        # Pick a random index
        index = Math.floor Math.random() * counter

        # Decrease counter by 1
        counter--

        # And swap the last element with it
        temp = array[counter]
        array[counter] = array[index]
        array[index] = temp

    return array

game =
  tile:
    width: 64
    height: 64
  grid:
    width: 14
    height: 14
  width: -> @grid.width * @tile.width
  height: -> @grid.height * @tile.height

  init: ->
    Crafty.init @width(), @height()
    Crafty.background 'rgb(100, 100, 100)'

    Crafty.scene 'Loading'

# -- Components --

Crafty.c 'Deck',
  init: ->
    #@requires 'Keyboard'
    @_cards = []
    @bind 'KeyDown', (e) ->
      if e.key == Crafty.keys.ENTER
        @nextCard()

  deck: (grid, highlight) ->
    @_grid = grid
    @_highlight = highlight
    return @

  nextCard: -> Crafty.e(@_cards.pop()).griddable(@_grid, @_highlight).position(2, 2)
  shuffle: ->
    shuffle @_cards
    return @

  # Takes an object of card types and quantities, and adds them to the deck.
  add: (types) ->
    Lazy(types).each (count, type) => Lazy.range(0, count).each => @_cards.push type
    return @

Crafty.c 'Grid',
  ready: true

  divisions: (h, v) ->
    @_divisions.h = h
    @_divisions.v = v

  cellSize: ->
    width: @w / @_divisions.h
    height: @h / @_divisions.v

  cell: (col, row) ->
    c = @cellSize()
    return {
      x: (col * c.width) + @x
      y: (row * c.height) + @y
      w: c.width
      h: c.height
    }

  cellAtPosition: (x, y) ->
    c = @cellSize()
    @cell Math.floor((x - @x) / c.width), Math.floor((y - @y) / c.height)

  drawGrid: (ctx, pos) ->
    ctx.beginPath()
    for i in [0..@_divisions.v]
      ctx.moveTo(i * @h / @_divisions.v, 0)
      ctx.lineTo(i * @h / @_divisions.v, @w)
    for i in [0..@_divisions.h]
      ctx.moveTo(0,  i * @w / @_divisions.h)
      ctx.lineTo(@h, i * @w / @_divisions.h)
    ctx.strokeStyle = 'black'
    ctx.stroke()

  init: ->
    @requires 'Canvas, 2D'

    @_divisions =
      h: 14
      v: 14

    @bind 'Draw', (e) =>
      @drawGrid(e.ctx, e.pos)

Crafty.c 'GridHighlight',
  ready: true
  _changed: true

  gridHighlight: (grid, color) ->
    @_grid = grid
    @_color = color

    size = grid.cellSize()
    @attr(x: 0, y: 0, w: size.width, size.height)
    return @

  init: ->
    @_globalZ = -100
    @requires 'Canvas, 2D'
    @bind 'Draw', (e) => @drawHighlight(e.ctx, e.pos)

  drawHighlight: (ctx, pos) ->
    ctx.strokeStyle = @_color
    ctx.strokeRect(pos._x + 1, pos._y + 1, pos._w - 2, pos._h - 2)

Crafty.c 'Griddable',
  init: ->
    @_globalZ = 2
    @requires 'Draggable, 2D'
    @attr w: game.tile.width, h: game.tile.height

  griddable: (grid, highlight) ->
    throw 'no no' if @_grid?
    @_grid = grid

    @bind 'StartDrag', ->
      @_globalZ = 999

    @bind 'StopDrag', (e) ->
      @_globalZ = 0
      cell = @_grid.cellAtPosition(@_x + @_w / 2, @_y + @_h / 2)
      @attr x: cell.x, y: cell.y

    if highlight?
      @_highlight = highlight
      @_highlight.visible = false

      @bind 'StopDrag', (e) ->
        @_highlight.visible = false

      @bind 'Dragging', ->
        @_highlight.visible = true
        cell = @_grid.cellAtPosition(@_x + @_w / 2, @_y + @_h / 2)
        @_highlight.attr cell

    return @

  position: (x, y) ->
    cell = @_grid.cell x, y
    @attr x: cell.x, y: cell.y
    return @

Crafty.c 'Tile',
  init: -> @requires '2D, Canvas, Griddable'

Crafty.c 'Mask',
  masked: (value) ->
    if value?
      @_maskObject.visible = value
    else
      return @_maskObject.visible

  mask: (sprite) ->
    @_maskObject.addComponent sprite
    return @

  init: ->
    @_maskObject = Crafty.e '2D, Canvas'
    @bind 'DoubleClick', => @masked(!@masked())
    @attach @_maskObject

Crafty.c 'TrenchTile',
  init: ->
    @requires 'Tile, Rotatable, Mask'
    @mask 'spr_trench_back'

Crafty.c 'Rotatable',
  init: ->
    @requires '2D, Mouse'
    @origin 'center'
    @bind 'MouseUp', (e) ->
      @rotation += 90 if e.mouseButton == Crafty.mouseButtons.RIGHT

Crafty.c 'StraightTrench',
  init: -> @requires 'TrenchTile, spr_trench_straight'

Crafty.c 'TTrench',
  init: -> @requires 'TrenchTile, spr_trench_t'

Crafty.c 'CrossTrench',
  init: -> @requires 'TrenchTile, spr_trench_cross'

Crafty.c 'BendTrench',
  init: -> @requires 'TrenchTile, spr_trench_bend'

# Loading scene
# -------------
# Handles the loading of binary assets such as images and audio files
Crafty.scene 'Loading', ->
  # Draw some text for the player to see in case the file
  #  takes a noticeable amount of time to load
  Crafty.e('2D, DOM, Text')
    .text('Loading...')
    .attr({ x: 0, y: game.height()/2 - 24, w: game.width() })
    #.css($text_css)

  # Load our sprite map image
  Crafty.load ['images/trench-tiles.png'], ->
    # Once the image is loaded...

    # Define the individual sprites in the image
    # Each one (spr_tree, etc.) becomes a component
    # These components' names are prefixed with "spr_"
    #  to remind us that they simply cause the entity
    #  to be drawn with a certain sprite
    Crafty.sprite 64, 'images/trench-tiles.png',
      spr_trench_back:     [0, 0]
      spr_trench_straight: [1, 0]
      spr_trench_t:        [2, 0]
      spr_trench_cross:    [3, 0]
      spr_trench_bend:     [4, 0]

    # Now that our sprites are ready to draw, start the game
    Crafty.scene 'Game'

Crafty.scene 'Game', ->
  grid = Crafty.e('Grid').attr(x: 0, y: 0, w: game.width(), h: game.height())
  highlight = Crafty.e('GridHighlight').gridHighlight(grid, 'white')
  trenchDeck = Crafty.e('Deck').deck(grid, highlight).add(
    StraightTrench: 20
    TTrench: 20
    CrossTrench: 20
    BendTrench: 20
  ).shuffle()
  console.dir trenchDeck._cards

  b = Crafty.e('BendTrench').griddable(grid, highlight).position(5,5)

window.addEventListener 'load', -> game.init()


