# Util -- to be moved to another file
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

    console.log "Adding layer!", name, components, offset, visible

    entity = Crafty.e("2D, Canvas, #{ components }")
    @attach(entity)
    entity.attr(x: offset.x, y: offset.y, z: @z)
    entity.visible = visible

    layers[name] = entity
    return entity

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
      maskEntity.visible = false if @ownedBy(e.player)

    @bind 'StopPeek', (e) ->
      maskEntity.visible = true if @ownedBy(e.player) and masked

    @bind 'OwnerChanged', (e) ->
      game = Crafty('GameManager')
      maskEntity.visible = false if game?.isPeeking(e.owner)

    return @


Crafty.c 'Lockable', init: ->

  # Private vars
  lockEntity = null
  isLocked = false

  # Constructor
  @lockable = ({ showSprite }) ->
    if showSprite
      @requires 'SpriteLayers'
      lockEntity = @addLayer 'Lock', { components: 'spr_lock', offset: { x: 32, y: 0 } }
    @lock()
    return @

  # Event subscription.
  @bind 'StartTurn', -> @unlock()
  @bind 'EndTurn', -> @lock()

  # API
  @isLocked = -> isLocked

  @lock = ->
    isLocked = true
    lockEntity.visible = true
    @trigger 'Lock'

  @unlock = ->
    isLocked = false
    lockEntity.visible = false
    @trigger 'Unlock'

# Draws the board grid.
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

# Highlight object that shows which grid cell is selected.
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

# Component that allows an object to be dragged and dropped onto the grid.
Crafty.c 'Griddable',
  init: -> @requires 'Draggable, 2D, Mouse'

  griddable: (@_grid, @_highlight, @_staticZ=2, @_dragZ=999) ->
    @attr z: @_staticZ
    cell = @_grid.cellSize()
    @origin cell.width / 2, cell.height / 2

    @bind 'Lock', -> @disableDrag()
    @bind 'Unlock', -> @enableDrag()
    @bind 'StartDrag', ->
      @attr z: @_dragZ

    @bind 'StopDrag', (e) ->
      @attr z: @_staticZ
      cell = @_grid.cellAtPosition(@_x + @_w / 2, @_y + @_h / 2)
      if cell?
        @attr(
          x: cell.x + (cell.w - @_w) / 2
          y: cell.y + (cell.h - @_h) / 2
        )

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


# Convenience component for anything that can be placed on the grid.
# NOTE: This is actually pretty pointless.
Crafty.c 'Tile',
  init: -> @requires 'Canvas, Griddable'

# Allows the entity to be rotated on right click.
Crafty.c 'Rotatable',
  init: ->
    @requires '2D, Mouse'
    @bind 'MouseUp', (e) ->
      @rotation += 90 if e.mouseButton == Crafty.mouseButtons.RIGHT

Crafty.c 'TrenchTile',
  init: -> @requires 'Tile, Rotatable, Lockable'

Crafty.c 'StraightTrench',
  init: -> @requires 'TrenchTile, spr_trench_straight'

Crafty.c 'TTrench',
  init: -> @requires 'TrenchTile, spr_trench_t'

Crafty.c 'CrossTrench',
  init: -> @requires 'TrenchTile, spr_trench_cross'

Crafty.c 'BendTrench',
  init: -> @requires 'TrenchTile, spr_trench_bend'

# Gives an 'owner' to the entity.
Crafty.c 'Ownable', init: ->
  _owner = null

  @owner = (player) ->
    if player?
      _owner = player
      @trigger 'OwnerChanged', owner: player
      return @
    return _owner

  @ownedBy = (player) -> return _owner == player

# Just the model part of a deck.
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


Crafty.c 'DrawDeck',
  init: ->
    @requires 'Deck, Mouse, Canvas, 2D, Lockable'

    @bind 'Click', (e) ->
      return if @isLocked?()
      if e.mouseButton == Crafty.mouseButtons.LEFT and @hasNextCard()
        @nextCard().attr(x: @x, y: @y).startDrag()

Crafty.c 'Unit', init: ->
  console.log "init unit"

  @requires 'Tile, Ownable, Mouse'
  @attr w: 64, h: 64, z: 10

  @bind 'OwnerChanged', (e) ->
    @addComponent "spr_p#{ e.owner }_rifleman, Maskable"
    @maskable("spr_p#{ e.owner }_back")
    @bind 'DoubleClick', -> if @isMasked() then @reveal() else @mask()

