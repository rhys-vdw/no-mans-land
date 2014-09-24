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
  margin:
    x: 300
    y: 100
  tile:
    width: 64
    height: 64
  grid:
    width: 14
    height: 14
  width: -> @grid.width * @tile.width
  height: -> @grid.height * @tile.height

  init: ->
    Crafty.init @width() + @margin.x, @height() + @margin.y, $('#game')[0]
    Crafty.background 'rgb(100, 100, 100)'
    Crafty.scene 'Loading'

    $status = $('#status')
    $nextTurn = $('#next-turn')

    $nextTurn.click (->
      gameStarted = false
      onTurn = false
      player = 1

      return (e) ->
        e.preventDefault()
        if not gameStarted
          onTurn = false
          player = 1
          gameStarted = true

          $status.text "Player #{ player }:"
          $nextTurn.text "Start Turn"
        else if onTurn
          onTurn = false
          Crafty.trigger 'EndTurn', player: player

          player = if player == 1 then 2 else 1
          $status.text "Player #{ player }:"
          $nextTurn.text "Start Turn"
        else
          onTurn = true
          $nextTurn.text "End Turn"
          Crafty.trigger 'StartTurn', player: nextPlayer
    )()

# -- Components --

Crafty.c 'Owned', owned: (@owner) ->

Crafty.c 'DrawDeck',
  init: ->
    @requires 'Deck, Mouse, Canvas, 2D'

    @bind 'Click', (e) ->
      if e.mouseButton == Crafty.mouseButtons.LEFT and @hasNextCard()
        @nextCard().attr(x: @x, y: @y).startDrag()

Crafty.c 'Deck',
  init: ->
    @_cards = []

  deck: (grid, highlight) ->
    @_grid = grid
    @_highlight = highlight
    return @

  hasNextCard: -> @_cards.length > 0
  nextCard: ->
    Crafty.e(@_cards.pop()).griddable(@_grid, @_highlight)

  shuffle: ->
    shuffle @_cards
    @trigger 'CardsShuffled', @_cards
    return @

  # Takes an object of card types and quantities, and adds them to the deck.
  add: (types) ->
    Lazy(types).each (count, type) => Lazy.range(0, count).each => @_cards.push type
    @trigger 'CardsAdded', types
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
    return if @isAt x, y
      c = @cellSize()
      @cell Math.floor((x - @x) / c.width), Math.floor((y - @y) / c.height)
    else
      undefined

  drawGrid: (ctx, pos) ->
    ctx.beginPath()
    for i in [0..@_divisions.h]
      x = pos._x + i * pos._h / @_divisions.v
      ctx.moveTo(x,          pos._y)
      ctx.lineTo(x, pos._h + pos._y)
    for i in [0..@_divisions.v]
      y = pos._y + i * pos._w / @_divisions.h
      ctx.moveTo(         pos._x, y)
      ctx.lineTo(pos._x + pos._w, y)
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
    @z = -100
    @requires 'Canvas, 2D'
    @bind 'Draw', (e) => @drawHighlight(e.ctx, e.pos)

  drawHighlight: (ctx, pos) ->
    ctx.strokeStyle = @_color
    ctx.strokeRect(pos._x + 1, pos._y + 1, pos._w - 2, pos._h - 2)

Crafty.c 'Griddable',
  init: ->
    @attr z: 2, w: game.tile.width, h: game.tile.height
    @requires 'Draggable, 2D, Mouse'

  griddable: (@_grid, @_highlight, @_staticZ=2, @_dragZ=999) ->

    @bind 'StartDrag', ->
      @attr z: @_dragZ

    @bind 'StopDrag', (e) ->
      @attr z: @_staticZ
      cell = @_grid.cellAtPosition(@_x + @_w / 2, @_y + @_h / 2)
      if cell?
        @attr x: cell.x, y: cell.y

    if @_highlight?
      @_highlight.visible = false

      @bind 'StopDrag', (e) ->
        @_highlight.visible = false

      @bind 'Dragging', ->
        cell = @_grid.cellAtPosition(@_x + @_w / 2, @_y + @_h / 2)
        if cell?
          @_highlight.visible = true
          @_highlight.attr cell
        else
          @_highlight.visible = false

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
    @_maskObject.attr z: @z
    @bind 'DoubleClick', => @masked(!@masked())
    @attach @_maskObject
    @bind 'Invalidate', ->
      if @_z != @_maskObject._z
        @_maskObject.attr z: @_z

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
  grid = Crafty.e('Grid').attr(x: game.margin.x / 2, y: game.margin.y / 2, w: game.width(), h: game.height())
  highlight = Crafty.e('GridHighlight').gridHighlight(grid, 'white')

  trenchDeck = Crafty.e 'DrawDeck, spr_trench_back'
      .deck(grid, highlight)
      .attr(
        x: game.margin.x / 4 - 32
        y: (game.height() + game.margin.y) / 2 - 32
      ).add(
    StraightTrench: 20
    TTrench: 20
    CrossTrench: 20
    BendTrench: 20
  ).shuffle()

window.addEventListener 'load', -> game.init()


