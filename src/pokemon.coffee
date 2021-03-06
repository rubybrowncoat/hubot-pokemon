# Description:
#   Get pokemon info.
#
# Dependencies:
#   joemon
#
# Configuration:
#   None
#
# Commands:
#   hubot (poke)dex (me) Pikachu - fuzzy pokemon name search that returns some basic pokémon info
#   hubot (poke)dex sprite (me) Pikachu - grabs a direct link to a sprite of the given pokemon
#   hubot (poke)dex art (me) Pikachu - grabs a direct link to the official art of the given pokemon
#   hubot (poke)dex moves (me) Pikachu - shows the moves that a pokemon can learn
#   hubot (poke)dex moves (me) Pikachu Tackle - shows how a pokemon learns a move, if they can
#   hubot (poke)dex move (me) Tackle - shows information about a move
#
# Author:
#   dualmoon

cheerio = require 'cheerio'
Pokemon = require 'joemon'
pokemon = new Pokemon()
Fuzzy = require 'fuzzyset.js'
pokeDex = pokemon.getPokedex()
pokeList = []
pokeList.push(item) for item in pokeDex.body.pokemon
pokeNames = []
pokeNames.push(item.name) for item in pokeDex.body.pokemon
pokeDict = []
for item in pokeList
  pokeDict[item.name] = item.resource_uri.split('/')[3]
pokeFuzzy = new Fuzzy(pokeNames)
totalMoves = pokemon.getMoves(1).body.meta.total_count
movesList = pokemon.getMoves(totalMoves).body.objects
movesNames = []
movesNames.push(item.name.replace '-', ' ') for item in movesList
movesDict = []
for item in movesList
  movesDict[item.name.replace '-', ' '] = item.resource_uri.split('/')[4]
movesFuzzy = new Fuzzy(movesNames)

getPokemonByName = (name) ->
  match = pokeFuzzy.get(name)[0][1]
  poke = pokemon.getPokemon(pokeDict[match]).body
getMoveByName = (name) ->
  match = movesFuzzy.get(name)[0][1]
  move = pokemon.getMove(movesDict[match]).body

String::capitalize = () ->
  @[0].toUpperCase() + @.substring(1)

module.exports = (robot) ->

  robot.respond /(?:poke)?dex sprite(?: me)? (\S+)$/im, (msg) ->
    preURI = "http://pokeapi.co"
    thePoke = getPokemonByName msg.match[1]
    spriteID = thePoke.sprites[0].resource_uri.split('/')[4]
    img = pokemon.getSprite spriteID
    msg.reply "#{preURI}#{img.body.image}"
    
  robot.respond /(?:poke)?dex(?: me)? (\S+)$/im, (msg) ->
    thePoke = getPokemonByName msg.match[1]
    types = []
    types.push(item.name.capitalize()) for item in thePoke.types
    evoTxt = "I don't evolve into anything!"
    if thePoke.evolutions.length > 0
      evos = []
      evos.push("#{item.to.capitalize()} via #{if item.method is 'other' then item.detail else item.method}") for item in thePoke.evolutions
      evoTxt = "I evolve into #{evos.join ' and '}!"
      evoTxt = evoTxt.replace('_', ' ')
    msg.reply "I am #{thePoke.name}. I am a #{types.join ' and '} pokemon! #{evoTxt}"

  robot.respond /(?:poke)?dex art(?: me)? (\S+)$/im, (msg) ->
    thePoke = getPokemonByName msg.match[1]
    robot.http("http://bulbapedia.bulbagarden.net/wiki/#{thePoke.name}")
      .get() (err, res, body) ->
        if err or res.statusCode isnt 200
         return "It's broke."
        $ = cheerio.load(body)
        img = $("a[title=\"#{thePoke.name}\"].image img")
        result = []
        if not img.attr('srcset')?
          result.push img.attr('src')
        else  
          if img.length is 1
            result.push(img.attr('srcset').split(', ')[1].split(' ')[0])
          else
            result.push(item.attribs.srcset.split(', ')[1].split(' ')[0]) for item in img
        msg.reply "Here's #{thePoke.name}: #{result.join ', '}"

  robot.respond /(?:poke)?dex moves(?: me)? (\S+)$/im, (msg) ->
    thePoke = getPokemonByName msg.match[1]
    text = "Here's the moves I can learn: "
    moves = []
    moves.push item.name for item in thePoke.moves
    msg.reply "#{text}#{moves.join ', '}"

  robot.respond /(?:poke)?dex moves(?: me)? (\S+) (\S+)$/im, (msg) ->
    thePoke = getPokemonByName msg.match[1]
    for item in thePoke.moves
      if item.name.toLowerCase() is msg.match[2].toLowerCase()
        if item.learn_type is "level up"
          msg.reply "#{thePoke.name} learns #{item.name} by gaining level #{item.level}"
        else
          msg.reply "#{thePoke.name} learns #{item.name} via #{item.learn_type}"
  robot.respond /(?:poke)?dex move(?: me)? (\S+(?: \S+)?)$/im, (msg) ->
    theMove = getMoveByName msg.match[1]
    msg.reply "#{theMove.name.replace '-', ' '}: #{theMove.description} [POW:#{theMove.power} ACC:#{theMove.accuracy} PP: #{theMove.pp}]"
