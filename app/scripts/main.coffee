
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

  @getLayer = (name) -> layers[name]

  @addLayer = (name, { components, offset, visible }) ->
    offset ?= x: 0, y: 0
    visible ?= true

    entity = Crafty.e("2D, Canvas, #{ components }")
    @attach(entity)
    entity.attr(x: offset.x, y: offset.y, z: @z)
    entity.visible = visible

    layers[name] = entity
    return entity


Crafty.c 'Unit',
  init: ->
    @requires 'Tile, Mask, Owned, Lockable'

  unit: ({ player }) ->
    @owned(player)
    @_backSprite = ''

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

  trenchDeck = Crafty.e 'DrawDeck, Draggable, spr_trench_back'
      .deck(grid, highlight)
      .lockable( showSprite: true )
      .attr(
        x: config.margin.x / 4 - 32
        y: (config.height() + config.margin.y) / 2 - 32
      )
      .add(
    StraightTrench: 20
    TTrench: 20
    CrossTrench: 20
    BendTrench: 20
  ).shuffle()

window.addEventListener 'load', -> config.init()


