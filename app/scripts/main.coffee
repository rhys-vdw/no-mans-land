
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
    ctx.stroke()

  init: ->
    @requires 'Canvas, 2D'

    @_divisions =
      h: 14
      v: 14

    @bind 'Draw', (e) => @drawGrid(e.ctx, e.pos)

Crafty.c 'Griddable',
  init: ->
    @requires 'Draggable'
    @attr w: game.tile.width, h: game.tile.height
    @bind 'StopDrag', (e) ->
      return unless @_grid?
      cell = @_grid.cellAtPosition(e.pageX, e.pageY)
      @attr x: cell.x, y: cell.y

  grid: (grid) ->
    @_grid = grid
    return @

  position: (x, y) ->
    cell = @_grid.cell x, y
    @attr x: cell.x, y: cell.y

Crafty.c 'Tile',
  init: -> @requires '2D, Canvas, Griddable'

Crafty.c 'TrenchTile',
  init: -> @requires 'Tile, Rotatable'

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
      spr_trench_straight: [0, 0]
      spr_trench_t:        [1, 0]
      spr_trench_cross:    [2, 0]
      spr_trench_bend:     [3, 0]

    # Now that our sprites are ready to draw, start the game
    Crafty.scene 'Game'

Crafty.scene 'Game', ->
  grid = Crafty.e('Grid').attr(x: 0, y: 0, w: game.width(), h: game.height())
  b = Crafty.e('BendTrench').grid(grid).position(5,5)

window.addEventListener 'load', -> game.init()


