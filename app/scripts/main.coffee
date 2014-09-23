
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
    console.dir Crafty
    console.dir @
    Crafty.init @width(), @height()
    Crafty.background 'rgb(100, 100, 100)'

    Crafty.scene 'Loading'

# -- Components --

Crafty.c 'Grid',
  init: ->
    @attr w: game.tile.width, h: game.tile.height
  position: (x, y) ->
    if x? and y?
      @attr x: x * game.tile.width, y: y * game.tile.height
    else
      return x: @x / game.tile.width, y: @y / game.tile.height

Crafty.c 'Tile',
  init: -> @requires '2D, Canvas, Grid'

Crafty.c 'StraightTrench',
  init: -> @requires 'Tile, spr_trench_straight'

Crafty.c 'TTrench',
  init: -> @requires 'Tile, spr_trench_t'

Crafty.c 'CrossTrench',
  init: -> @requires 'Tile, spr_trench_cross'

Crafty.c 'BendTrench',
  init: -> @requires 'Tile, spr_trench_bend'

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
  b = Crafty.e('BendTrench').position(5,5)

window.addEventListener 'load', -> game.init()


