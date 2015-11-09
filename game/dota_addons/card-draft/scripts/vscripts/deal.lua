require("players")
require("events")
require("inputs")
require("lib/timers")

teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}

roundTime = 15
timeRemaining = roundTime

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
      deal = 1,
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

   local dealCard = function(list, cardType)
      -- Randomly pick from the list of ultimates.
      local i = RandomInt(1, #list)
      local dealt = list[i]

      table.remove(list, i)

      return {type = cardType, name = dealt}
   end

   local dealStartingHand = function(playerId)
      local hand = {}
      local picks = {}
      
      handsByPlayer[playerId] = hand
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

   -- TODO: remove all this dead code once I'm sure I've filtered abilities correctly.
   -- print("all abilities")
   -- for i, ability in ipairs(normalAbilities) do
   --    print(i, ability)
   -- end
   -- for i, ability in ipairs(ultimates) do
   --    print(i, ability)
   -- end

   forEachPlayer(dealStartingHand)
   setupPassToPlayer()
   listenToPlayerEvent(
      "player-drafted-card",
      playerDraftedCard
   )
   waitForAllPlayers(sendHandsToPlayers)
   Timers:CreateTimer({useGameTime = false, callback = notifyPlayersOfTimeRemaining})
end

-- Decide which player we'll pass our hand to.
function setupPassToPlayer()
   for teamNumber, team in ipairs(teams) do
      local playerCount = PlayerResource:GetPlayerCountForTeam(team)

      if playerCount ~= 0 then
	 for i = 1, playerCount do
	    -- Try to pass to the player with the same number on the next team
	    local playerId = PlayerResource:GetNthPlayerIDOnTeam(team, i)
	    local nextPlayerPosition = i
	    local nextTeamNumber = (teamNumber + 1)

	    -- If there are no more teams, try to pass to the player with the next number on the first team.
	    if nextTeamNumber > #teams then
	       nextPlayerPosition = nextPlayerPosition + 1
	       nextTeamNumber = 1
	    end
	    
	    local nextTeam = teams[nextTeamNumber]

	    -- If there are not enough players on the team, pass to the first player on the first team.
	    if nextPlayerPosition > PlayerResource:GetPlayerCountForTeam(nextTeam) then
	       nextPlayerPosition = 1
	       nextTeamNumber = 1
	       nextTeam = teams[nextTeamNumber]
	    end

	    passToPlayer[playerId] = PlayerResource:GetNthPlayerIDOnTeam(nextTeam, nextPlayerPosition)
	 end
      end
   end
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

   -- Check if this pick has ended the game.
   if not checkForEnd() then
      -- Otherwise, see if it's time to pass our hands on.
      maybeNextRound()
   end
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

      -- Assign all players the heroes and abilities they chose.
      forEachPlayer(selectHeroAndAbilities)

      -- Good luck, have fun.
      PauseGame(false)

      return true
   else
      return false
   end
end

-- If all the players have picked a card (or been forced to pick a card, or to pass), move the hands around.
function maybeNextRound()
   if forAllPlayers(hasPicked) then
      nextRound()
   end
end

function nextRound()
   forEachPlayer(pickupHand)
   sendHandsToPlayers()
end

function pickupHand(playerId)
   handsByPlayer[playerId] = nextHandsByPlayer[playerId]
end

function hasPicked(playerId)
   return #handsByPlayer[playerId] == 0
end

function sendHandsToPlayers()
   timeRemaining = roundTime
   forEachPlayer(sendHandToPlayer)
   forEachPlayer(testForAutomaticPlay)
end

function notifyPlayersOfTimeRemaining()
   timeRemaining = timeRemaining - 1
   CustomGameEventManager:Send_ServerToAllClients("round-timer-count", {time = timeRemaining})
   if timeRemaining <= 0 then
      timeRemaining = roundTime
      forcePlayersToRandom()
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
      playerDraftedCard(
	 playerId,
	 randomCard(playableCards)
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
   for i = 0, hero:GetAbilityCount() do
      local abilityToRemove = hero:GetAbilityByIndex(i)
      
      if abilityToRemove ~= nil then
	 local toRemove = abilityToRemove:GetAbilityName()

	 if toRemove ~= "attribute_bonus" then
	    hero:RemoveAbility(toRemove)
	 end
      end
   end
end

function selectHeroAndAbilities(playerId)
   local picks = picksByPlayer[playerId]
   local player = PlayerResource:GetPlayer(playerId)

   CreateHeroForPlayer(picks["hero"][1], player)

   local hero = player:GetAssignedHero()

   clearHeroAbilities(hero)

   -- Add the custom abilities they picked.
   for _, ability in ipairs(picks["ability"]) do
      hero:AddAbility(ability)
   end

   hero:AddAbility(picks["ultimate"][1])

   -- TODO: add sub-abilities
end
