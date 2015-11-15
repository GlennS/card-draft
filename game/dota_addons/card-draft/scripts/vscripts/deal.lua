require("players")
require("events")
require("inputs")
require("lib/timers")

teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}

cardDraftFinished = false

-- Intermissions happen before each round, to allow players to see what they picked / were forced to pick etc.
-- The new hand will be picked up at the end of the intermission.
roundLength = 15
roundTimeRemaining = roundLength
intermissionLength = 3
intermissionTimeRemaining = intermissionLength

maxPlayersInTeam = 5

-- Types and quantities of cards:
--- Dealt in initial hand
--- Which can be picked by the player over all hands
cardCounts = {
   ability = {
      deal = 4,
      pick = 3
   },
   ultimate = {
      deal = 2,
      pick = 1
   },
   hero = {
      deal = 2,
      pick = 1
   }
}

function deal()
   print("Entering Card Draft deal phase")

   -- Pause to prevent standard hero picking from happening.
   PauseGame(true)

   -- Load all possible options.
   local allHeroes = loadHeroes()
   local allAbilities = loadAbilities(allHeroes)
   local options = {
      hero = loadHeroes(),
      ability = allAbilities["normal"],
      ultimate = allAbilities["ultimates"]
   }

   handsByPlayer = {}
   nextHandsByPlayer = {}
   picksByPlayer = {}
   passToPlayer = {}

   local onCacheSuccess = function()
      -- No-op
   end
   
   local preCache = function(name, cardType)
      if cardType == "hero" then
	 PrecacheUnitByNameAsync(name, onCacheSuccess)
	 
      elseif cardType == "ability" or cardType == "ultimate" then
	 PrecacheItemByNameAsync(name, onCacheSuccess)
      else
	 error("Unknown type of card " .. cardType)
      end
   end

   local dealCard = function(list, cardType)
      -- Randomly pick from the list of ultimates.
      local i = RandomInt(1, #list)
      local dealt = list[i]

      table.remove(list, i)

      preCache(dealt, cardType)

      return {type = cardType, name = dealt}
   end

   local dealStartingHand = function(playerId)
      local hand = {}
      local picks = {}

      handsByPlayer[playerId] = {}
      nextHandsByPlayer[playerId] = hand
      picksByPlayer[playerId] = picks

      for cardType, quantities in pairs(cardCounts) do
	 picks[cardType] = {}
	 
	 for i = 1, quantities["deal"] do
	    table.insert(
	       hand,
	       dealCard(options[cardType], cardType)
	    )
	 end
      end
   end

   forEachPlayer(dealStartingHand)
   setupPassToPlayer()
   listenToPlayerEvent(
      "player-drafted-card",
      playerDraftedCard
   )
   waitForAllPlayers(
      function()
	 Timers:CreateTimer({useGameTime = false, callback = notifyPlayersOfTimeRemaining})	 
      end
   )
end

-- Decide which player we'll pass our hand to.
function setupPassToPlayer()
   local firstPlayerId = nil
   local playerId = nil
   local nextPlayerId = nil

   -- Iterate through by team and player number.
   -- Each player will pass to the next player in this iteration.
   for i = 1, maxPlayersInTeam do
      for teamNumber, team in ipairs(teams) do
	 local playerCount = PlayerResource:GetPlayerCountForTeam(team)

	 if i <= playerCount then
	    local nextPlayerId = PlayerResource:GetNthPlayerIDOnTeam(team, i)

	    if firstPlayerId == nil then
	       firstPlayerId = nextPlayerId
	    end

	    if playerId ~= nil then
	       passToPlayer[playerId] = nextPlayerId
	    end

	    playerId = nextPlayerId
	 end
      end
   end

   -- Close the circle
   passToPlayer[playerId] = firstPlayerId
end

-- Finds the location of a card in the player's hand
function cardInHand(playerId, card)
   local hand = handsByPlayer[playerId]

   for i, handCard in pairs(hand) do
      if handCard["type"] == card["type"] and handCard["name"] == card["name"] then
	 return i
      end
   end

   return nil
end

function playerDraftedCard(playerId, card)
   local cardInHandIndex = cardInHand(playerId, card)
   if cardInHandIndex == nil then
      -- You're not allowed to pick that...
      print("Player attempted to draft card which was not in their hand", playerId, card["name"])
      return
   end

   local cardType = card["type"]

   if not playerCanPickCard(playerId, cardType) then
      -- You've already picked all of those you can have...
      print("Player attempted to draft card of a type they have already filled", playerId, card["type"])
      return
   end

   local picks = picksByPlayer[playerId]
   local hand = handsByPlayer[playerId]
   local cardName = card["name"]

   -- Add that card to the player's picks, remove it from their hand.
   table.insert(picks[cardType], cardName)
   table.remove(hand, cardInHandIndex)

   -- Pass our hand to the next player, and take ours away so we can't pick from it again.
   nextHandsByPlayer[passToPlayer[playerId]] = hand
   handsByPlayer[playerId] = {}

   -- Send an event back to the player to confirm their choice (this is mainly useful for when we are forcing an automatic or random choice).
   local player = PlayerResource:GetPlayer(playerId)
   CustomGameEventManager:Send_ServerToPlayer(player, "player-pick-confirmed", card)

   -- See if it's time for the round to end.
   maybeNextIntermission()
end

-- True if the player can still pick cards of this type.
function playerCanPickCard(playerId, cardType)
   local pickedSoFar = picksByPlayer[playerId][cardType]
   local numberAllowed = cardCounts[cardType]["pick"]

   return #pickedSoFar < numberAllowed
end

-- True if the player can still pick at least one type of card.
function playerCanPickAnything(playerId)
   for cardType, _ in pairs(cardCounts) do
      if playerCanPickCard(playerId, cardType) then
	 return true
      end
   end
   
   return false
end

function checkForEnd()
   -- Check if all players have made all their picks.
   if not forAnyPlayer(playerCanPickAnything) then

      PauseGame(false)
      
      cardDraftFinished = true

      -- Good luck, have fun.
      return true
   else
      return false
   end
end

-- If all the players have picked a card (or been forced to pick a card, or to pass), move the hands around.
function maybeNextIntermission()
   if forAllPlayers(hasPicked) then
      nextIntermission()
   end
end

function pickupHand(playerId)
   handsByPlayer[playerId] = nextHandsByPlayer[playerId]
end

function hasPicked(playerId)
   return #handsByPlayer[playerId] == 0
end

function sendHandsToPlayers()
   forEachPlayer(sendHandToPlayer)
   forEachPlayer(testForAutomaticPlay)
   -- If no-one can play, end the round immediately.
   maybeNextIntermission()
end

function nextRound()
   -- There might not be any more rounds, check that first.
   if not checkForEnd() then
      -- Intermission over. Give everyone their new hands and move back to the drafting phase.
      intermissionTimeRemaining = nil
      roundTimeRemaining = roundLength
      forEachPlayer(pickupHand)
      sendHandsToPlayers()
   end
end

function nextIntermission()
   -- Round over. Force anyone left to random, move to intermission.
   intermissionTimeRemaining = intermissionLength
   roundTimeRemaining = nil
   forcePlayersToRandom()
end

function notifyPlayersOfTimeRemaining()
   if cardDraftFinished then
      -- Game over man, game over.
      return false

   elseif intermissionTimeRemaining ~= nil then
      -- We're in an intermission.
      intermissionTimeRemaining = intermissionTimeRemaining - 1

      if intermissionTimeRemaining <= 0 then
	 nextRound()
      else
	 CustomGameEventManager:Send_ServerToAllClients("round-timer-count", {value = intermissionTimeRemaining, phase = "intermission"})
      end
   else
      -- We're in the main drafting phase.
      roundTimeRemaining = roundTimeRemaining - 1

      if roundTimeRemaining <= 0 then
	 nextIntermission()
      else
	 CustomGameEventManager:Send_ServerToAllClients("round-timer-count", {value = roundTimeRemaining, phase = "draft"})
      end
   end

   return 1
end

-- Force all the remaining players to choose randomly.
function forcePlayersToRandom()
   forEachPlayer(forcePlayerToRandom)
end

-- Check if the player still has to choose this round.
-- If they do, force them to choose randomly from the cards they are allowed to pick.
function forcePlayerToRandom(playerId)
   local playableCards = getPlayableCards(playerId)
   if #playableCards > 0 then
      local randomed = randomCard(playableCards)
      randomed["reason"] = "random"
      
      playerDraftedCard(
	 playerId,
	 randomed
      )
   end
end

function randomCard(cards)
   return cards[RandomInt(1, #cards)]
end

function testForAutomaticPlay(playerId)
   local playableCards = getPlayableCards(playerId)

   if #playableCards == 0 then
      -- We have no choices, so we pass the hand on.
      nextHandsByPlayer[passToPlayer[playerId]] = handsByPlayer[playerId]
      handsByPlayer[playerId] = {}
      
   elseif #playableCards == 1 then
      -- We've only got one choice: force it.
      playableCards[1]["reason"] = "forced"
      playerDraftedCard(playerId, playableCards[1])
   end
end

function getPlayableCards(playerId)
   local hand = handsByPlayer[playerId]
   local playable = {}

   for _, card in ipairs(handsByPlayer[playerId]) do
      if playerCanPickCard(playerId, card["type"]) then
	 table.insert(playable, card)
      end
   end

   return playable
end

function sendHandToPlayer(playerId)
   local player = PlayerResource:GetPlayer(playerId)
   CustomGameEventManager:Send_ServerToPlayer(player, "player-passed-hand", handsByPlayer[playerId])
end

function clearHeroAbilities(hero)
   for i = 0, (hero:GetAbilityCount() - 1) do
      local abilityToRemove = hero:GetAbilityByIndex(i)
      
      if abilityToRemove ~= nil then
	 local toRemove = abilityToRemove:GetAbilityName()

	 if toRemove ~= "attribute_bonus" then
	    hero:RemoveAbility(toRemove)
	 end
      end
   end
end

function assignAllHeroes()
   -- Assign all players the heroes and abilities they chose.
   forEachPlayer(selectHeroAndAbilities)
end

function selectHeroAndAbilities(playerId)
   local picks = picksByPlayer[playerId]
   local player = PlayerResource:GetPlayer(playerId)
   local heroName = picks["hero"][1]

   CreateHeroForPlayer(heroName, player)
   local hero = player:GetAssignedHero()

   clearHeroAbilities(hero)

   -- Add the custom abilities they picked.
   for _, ability in ipairs(picks["ability"]) do
      hero:AddAbility(ability)
   end

   hero:AddAbility(picks["ultimate"][1])
end
