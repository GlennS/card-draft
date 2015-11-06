teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}

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
   local allAbilities = loadAbilities()
   local options = {
      hero = loadHeroes(),
      ability = allAbilities["normal"],
      ultimate = allAbilities["ultimates"]
   }

   handsByPlayer = {}
   nextHandsByPlayer = {}
   picksByPlayer = {}
   passToPlayer = {}

   function dealCard(list, cardType)
      -- Randomly pick from the list of ultimates.
      local i = math.random(#list)
      local dealt = list[i]

      table.remove(list, i)

      return {type = cardType, name = dealt}
   end

   -- print("all abilities")
   -- for i, ability in ipairs(normalAbilities) do
   --    print(i, ability)
   -- end
   -- for i, ability in ipairs(ultimates) do
   --    print(i, ability)
   -- end

   forEachPlayer(dealStartingHand)
   setupPassToPlayer()
   CustomGameEventManager:RegisterListener("player-drafted-card", playerDraftedCard)
   sendHandsToPlayers()
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
	    
	    local nextTeam = teams[nextTeam]

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

function dealStartingHand(playerId)
   local hand = {}
   local picks = {}
   
   handsByPlayer[playerId] = hand
   picksByPlayer[playerId] = picks

   for cardType, quantities in pairs(cardCounts) do
      picks[cardType] = []
      
      for i = 1, quantities["deal"] do
	 hand[cardType .. i] = dealCard(options[cardType], cardType)
      end
   end
end

-- Finds the location of a card in the player's hand
function cardInHand(playerId, card)
   local hand = handsByPlayer[playerId]

   for i, cardInHand in pairs(hand) do
      if cardInHand["type"] == card["type"] && cardInHand["name"] == card["name"] then
	 return i
      end
   end

   return false
end

function playerDraftedCard(playerId, card)
   local cardHandIndex = cardInHand(playerId, card)
   if not cardInHandIndex then
      -- You're not allowed to pick that...
      return
   end

   local cardType = card["type"]

   if not playerCanPickCard(playerId, cardType) then
      -- You've already picked all of those you can have...
      return
   end

   local picks = picksByPlayer[playerId]
   local hand = handsByPlayer[playerId]
   local cardName = card["name"]

   -- Add that card to the player's picks, remove it from their hand.
   table.insert(picks[cardType], cardName)
   table.remove(hand, cardInHandIndex)

   -- Pass our hand to the next player, and take ours away so we can't pick from it again.
   nextHandsByPlayer[passToPlayer(playerId)] = hand
   handsByPlayer[playerId] = {}

   -- Check if this pick has ended the game.
   if not checkForEnd() then
      -- Otherwise, see if it's time to pass our hands on.
      maybePassHands()
   end
end

-- True if the player can still pick cards of this type.
function playerCanPickCard(playerId, cardType)
   local pickedSoFar = picksByPlayer[playerId][cardType]
   local numberAllowed = cardCounts[cardType]["pick"]

   return #picksSoFar < numberAllowed
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
function maybePickupNextHands()
   if forAllPlayers(hasPicked) then
      forEachPlayer(pickupHand)
      sendHandsToPlayers()
   end
end

function pickupHand(playerId)
   handsByPlayer[playerId] = nextHandsByPlayer[playerId]
end

function hasPicked(playerId)
   return #handsByPlayer[playerId] > 0
end

-- Strictly speaking we could do this more efficienctly by halting as soon as we git a failure.
-- In practice, we don't care about performance in any of this code.
function forAnyPlayer(predicate)
   local accum = false
   local doTest = function(playerId)
      if predicate(playerId) then
	 accum = true
      end
   end

   forEachPlayer(doTest)

   return accum
end

-- Returns true if the predicate is true for all players.
function forAllPlayers(predicate)
   local accum = true
   local doTest = function(playerId)
      if not predicate(playerId) then
	 accum = false
      end
   end
   
   return accum
end

-- Execute a function for every player in the game.
function forEachPlayer(f)
   for _, team in ipairs(teams) do
      local playerCount = PlayerResource:GetPlayerCountForTeam(team)

      if playerCount ~= 0 then
	 for i = 1, playerCount do
	    local playerId = PlayerResource:GetNthPlayerIDOnTeam(team, i)
	    f(playerId)
	 end
      end
   end
end

function sendHandsToPlayers()
   forEachPlayer(sendHandToPlayer)
end

function sendHandToPlayer(playerId)
   print("sending to player", playerId)
   local player = PlayerResource:GetPlayer(playerId)
   CustomGameEventManager:Send_ServerToPlayer(player, "player-passed-hand", handsByPlayer[playerId])
end

-- TODO: we'd prefer not to have to distribute the npc_heroes.txt and npc_abilities.txt files ourselves - is there some better way?
function loadHeroes()
   -- Returns a list of all the heroes in Dota 2.
   local heroes = LoadKeyValues("scripts/data/npc_heroes.txt")
   forbiddenHeroes = {"npc_dota_hero_base", "Version"}
   local heroNames = {}

   for name, _ in pairs(heroes) do
      local ok = true
      for i, badName in ipairs(forbiddenHeroes) do
	 if name == badName then
	    ok = false
	    break
	 end
      end

      if ok then
	 table.insert(heroNames, name)
      end
   end

   return heroNames
end

function loadAbilities()
   -- Returns a list of all the abilities in Dota 2, divided up by whether they are an ultimate or normal skill.
   local normal = {}
   local ultimates = {}

   local abilities = LoadKeyValues("scripts/data/npc_abilities.txt")

   for name, ability in pairs(abilities) do
      if isPickableAbility(name, ability) then
	 if (ability["AbilityType"] == "DOTA_ABILITY_TYPE_ULTIMATE") then
	    table.insert(ultimates, name)
	 else
	    table.insert(normal, name)
	 end
      end
   end

   return {normal = normal, ultimates = ultimates}
end

function isPickableAbility(name, ability)
   local forbiddenBehaviours = {"DOTA_ABILITY_BEHAVIOR_HIDDEN", "DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE", "DOTA_ABILITY_BEHAVIOR_ITEM"}
   local forbiddenNames = {"Version", "ability_base"}

   for _, forbidden in pairs(forbiddenNames) do
      if (name == forbidden) then
	 return false
      end
   end

   local behaviour = ability["AbilityBehavior"]

   if (behaviour == nil) then
      return true
   end

   for _, forbidden in pairs(forbiddenBehaviours) do
      if string.find(behaviour, forbidden) then
	 return false
      end
   end
   
   return true
end

function selectHeroAndAbilities(playerId)
   local picks = picksByPlayer(playerId)
   local player = PlayerResource:GetPlayer(playerId)

   CreateHeroForPlayer(picks["hero"], player)

   local hero = player:GetAssignedHero()

   -- Remove the player's default abilities.
   while hero.GetAbilityCount() > 0 do
      hero.removeAbility(
	 hero.getAbilityByIndex(1):GetAbilityName()
      )
   end

   -- Add the custom abilities they picked.
   for _, ability in ipairs(picks["ability"]) do
      hero.addAbility(ability)
   end

   hero.addAbility(picks["ultimate"])

   -- TODO: add sub-abilities
end
