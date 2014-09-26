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

game = null
config =
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

    game = Crafty.e('GameManager')

    $status = $('#status')
    $nextTurn = $('#next-turn')

    $nextTurn.click (e) ->
      e.preventDefault()
      if game._gameStarted
        if game._onTurn
          game.endTurn()
          game.nextTurn()
          $status.text "Player #{ game._player }:"
          $nextTurn.text "Start Turn"
        else
          game.startTurn()
          $nextTurn.text "End Turn"
      else
        game.startGame()
        $status.text "Player #{ game._player }:"
        $nextTurn.text "Start Turn"

# -- Components --

Crafty.c 'GameManager',
  init: ->
    @requires 'Keyboard'

    @bind 'KeyDown', (e) -> @_keydown e
    @bind 'KeyUp', (e) -> @_keyup e

    @_started = false
    @_player = null
    @_onTurn = false

    Crafty.scene 'Loading'

  activePlayer: -> @_onTurn and @_player

  isPeeking: (player) -> return @_isPeeking and @_player == player

  startGame: ->
    @_onTurn = false
    @_player = 1
    @_gameStarted = true
    Crafty.trigger 'StartGame'

  startTurn: ->
    @_onTurn = true
    Crafty.trigger 'StartTurn', player: @_player

  nextTurn: ->
    @_player = if @_player == 1 then 2 else 1

  endTurn: ->
    @_onTurn = false
    @_stopPeek()
    Crafty.trigger 'EndTurn', player: @_player

  _startPeek: ->
    @_isPeeking = true
    Crafty.trigger 'StartPeek', player: @_player

  _stopPeek: ->
    @_isPeeking = false
    @_peekToggled = false
    Crafty.trigger 'StopPeek', player: @_player

  _togglePeek: ->
    if @_peekToggled == true
      @_stopPeek()
    else
      @_peekToggled = true
      @_startPeek()

  _keydown: (e) ->
    if e.keyCode == Crafty.keys.P and @_onTurn
      @_togglePeek()
    if e.keyCode == Crafty.keys.ENTER and @_onTurn
      @_startPeek()

  _keyup: (e) ->
    if e.keyCode == Crafty.keys.ENTER and !@_peekToggled
      @_stopPeek()

Crafty.c 'Owned',
  owned: (@_owner) ->
    @trigger 'OwnerChanged', owner: @_owner
    @

Crafty.c 'DrawDeck',
  init: ->
    @requires 'Deck, Mouse, Canvas, 2D, Lockable'

    @bind 'Click', (e) ->
      return if @isLocked?()
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
    @attr z: 2, w: config.tile.width, h: config.tile.height
    @requires 'Draggable, 2D, Mouse'

  griddable: (@_grid, @_highlight, @_staticZ=2, @_dragZ=999) ->

    @bind 'Lock', -> @disableDrag()
    @bind 'Unlock', -> @enableDrag()
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

Crafty.c 'Lockable',
  _lockEntity: null
  _zOffset: 0
  _isLocked: false
  init: ->
    @_lockEntity = Crafty.e('2D, Canvas').attr(z: @z)
    @attach(@_lockEntity)
    @_lockEntity.attr(x: 32, y: 0)

    @bind 'Invalidate', ->
      z = @_lockEntity._z + @_zOffset
      @_lockEntity.attr(z: z) if @_z != z

    # Automatically lock offturn.
    @bind 'StartTurn', -> @unlock()
    @bind 'EndTurn', -> @lock()

    if game._onTurn
      @unlock()
    else
      @lock()

  isLocked: -> @_isLocked

  lockable: ({ sprite, offset }) ->
    @_lockEntity.addComponent(sprite)
    @_zOffset = offset
    @trigger 'Invalidate'
    return @

  lock: ->
    @_isLocked = true
    @_lockEntity.visible = true
    @trigger 'Lock'

  unlock: ->
    @_isLocked = false
    @_lockEntity.visible = false
    @trigger 'Unlock'

Crafty.c 'Maskable', init: ->
  masked = false
  maskEntity = null

  setMasked = (value) ->
    masked = value
    maskEntity.visible = value

  @isMasked = -> masked
  @mask = -> setMasked(true)
  @reveal = -> setMasked(false)

  @maskable = (sprite) ->
    @requires 'SpriteLayers'
    maskEntity = @addLayer('Mask', components: sprite).attr visible: true
    masked = true

    # Bind to global events to temporarily show tokens.

    @bind 'StartPeek', (e) ->
      maskEntity.visible = false if @_owner == e.player

    @bind 'StopPeek', (e) ->
      maskEntity.visible = true if @_owner == e.player and masked

    @bind 'OwnerChanged', (e) ->
      maskEntity.visible = false if game.isPeeking(e.owner)

    return @

Crafty.c 'SpriteLayers', init: ->
  @requires '2D'

  # Private vars

  layers = {}

  # Update the layer z depths whenever this changes layers. This ensures the
  # token is never higher than the mask.
  @bind 'Invalidate', ->
    for name, entity of layers
      entity.attr(z: @_z) if entity._z != @_z

  # Public interface

  @getLayer = (sprite) -> layers[sprite]

  @addLayer = (name, { components, offset, visible }) ->
    offset ?= x: 0, y: 0
    visible ?= true

    entity = Crafty.e("2D, Canvas, #{ components }")
    entity.attr(x: offset.x, y: offset.y, z: @z)
    entity.visible = visible
    @attach(entity)

    layers[name] = entity
    return entity


Crafty.c 'Unit',
  init: ->
    @requires 'Tile, Mask, Owned, Lockable'

  unit: ({ player }) ->
    @owned(player)
    @_backSprite = ''

Crafty.c 'TrenchTile',
  init: -> @requires 'Tile, Rotatable, Lockable'

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
    .attr({ x: 0, y: config.height()/2 - 24, w: config.width() })
    #.css($text_css)

  # Load our sprite map image
  Crafty.load ['images/trench-tiles.png'], ->
    # Once the image is loaded...

    Crafty.sprite 64, 'images/trench-tiles.png',
      spr_trench_back:     [0, 0]
      spr_trench_straight: [1, 0]
      spr_trench_t:        [2, 0]
      spr_trench_cross:    [3, 0]
      spr_trench_bend:     [4, 0]

    Crafty.sprite 32, 'images/lock.png',
      spr_lock:     [0, 0]

    Crafty.sprite 32, 'images/units.png',
      spr_p1_back:     [0, 0]
      spr_p2_back:     [0, 1]
      spr_p1_rifleman: [1, 0]
      spr_p2_rifleman: [1, 1]

    # Now that our sprites are ready to draw, start the game
    Crafty.scene 'Game'

Crafty.scene 'Game', ->
  grid = Crafty.e('Grid').attr(x: config.margin.x / 2, y: config.margin.y / 2, w: config.width(), h: config.height())
  highlight = Crafty.e('GridHighlight').gridHighlight(grid, 'white')

  trenchDeck = Crafty.e 'DrawDeck, spr_trench_back'
      .deck(grid, highlight)
      .attr(
        x: config.margin.x / 4 - 32
        y: (config.height() + config.margin.y) / 2 - 32
      ).lockable(
        sprite: 'spr_lock'
        offset: 2
      ).add(
    StraightTrench: 20
    TTrench: 20
    CrossTrench: 20
    BendTrench: 20
  ).shuffle()

window.addEventListener 'load', -> config.init()


