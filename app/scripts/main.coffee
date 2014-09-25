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
    console.log 'game', game

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
    console.log "init?"
    @requires 'Keyboard'

    @bind 'KeyDown', (e) -> @_keydown e
    @bind 'KeyUp', (e) -> @_keyup e

    @_started = false
    @_player = null
    @_onTurn = false

    Crafty.scene 'Loading'

  activePlayer: -> @_onTurn and @_player

  isRevealing: (player) -> return @_isRevealing and @_player == player

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
    Crafty.trigger 'EndTurn', player: @_player

  _keydown: (e) ->
    if e.keyCode == Crafty.keys.ENTER and @_onTurn
      Crafty.trigger 'Reveal', player: @_player
      @_isRevealing = true

  _keyup: (e) ->
    if e.keyCode == Crafty.keys.ENTER
      Crafty.trigger 'Hide', player: @_player
      @_isRevealing = false

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
    console.log "Craeting a tile owned by ", game.activePlayer()
    Crafty.e(@_cards.pop()).griddable(@_grid, @_highlight).owned(game.activePlayer())

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

Crafty.c 'Lockable', do ->
  lockEntity = null
  zOffset = 0
  isLocked = true
  return {
    init: ->
      lockEntity = Crafty.e('2D, Canvas').attr(z: @z)
      @attach(lockEntity)
      lockEntity.attr(x: 32, y: 0)

      @bind 'Invalidate', ->
        z = lockEntity._z + zOffset
        lockEntity.attr(z: z) if @_z != z

      # Automatically lock offturn.
      @bind 'StartTurn', -> @unlock()
      @bind 'EndTurn', -> @lock()

      @lock()

    isLocked: -> isLocked

    lockable: ({ sprite, offset }) ->
      lockEntity.addComponent(sprite)
      zOffset = offset
      @trigger 'Invalidate'
      return @

    lock: ->
      isLocked = true
      lockEntity.visible = true
      @trigger 'Lock'

    unlock: ->
      isLocked = false
      lockEntity.visible = false
      @trigger 'Unlock'
  }

Crafty.c 'Mask',
  masked: (value) ->
    if value?
      @_masked = value
      @_maskObject.visible = value
    else
      return @_masked

  mask: (sprite) ->
    @_maskObject.addComponent sprite
    return @

  init: ->
    @_masked = true
    @_maskObject = Crafty.e '2D, Canvas'
    @_maskObject.attr z: @z
    @attach @_maskObject

    # TEMP: double click toggles visibility of token
    @bind 'DoubleClick', => @masked(!@masked())

    # Update the child z depth whenever this changes layers. This ensures the
    # token is never higher than the mask.
    @bind 'Invalidate', ->
      if @_z != @_maskObject._z
        @_maskObject.attr z: @_z

    # Bind to global events to temporarily show tokens.
    @bind 'Reveal', (e) ->
      if @_owner == e.player
        @_maskObject.visible = false

    @bind 'Hide', (e) ->
      if @_owner == e.player and @_masked
        @_maskObject.visible = true

    # Also update these live when ownership changes.
    @bind 'OwnerChanged', (e) ->
      if game.isRevealing(e.owner)
        @_maskObject.visible = false

Crafty.c 'TrenchTile',
  init: ->
    @requires 'Tile, Rotatable, Mask, Owned'
    @mask 'spr_trench_back'
    @bind 'StartTurn', (e) ->
      if e.player == @_owner
        @masked(false)

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

    Crafty.sprite 32, 'images/lock.png',
      spr_lock:     [0, 0]

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


