abilitiesPerHand = 4
ultimatesPerHand = 2
heroesPerHand = 1

function deal()
   print("Entering Card Draft deal phase")
   
   -- Pause to prevent standard hero picking from happening.
   PauseGame(true)

   -- Load all possible options.
   local allHeroes = loadHeroes()
   local allAbilities = loadAbilities()
   local normalAbilities = allAbilities["normal"]
   local ultimates = allAbilities["ultimates"]

   handsByPlayer = {}
   picksByPlayer = {}

   function dealCard(list)
      -- Randomly pick from the list of ultimates.
      local i = math.random(#list)
      local dealt = list[i]

      table.remove(list, i)

      return dealt
   end

   local teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}

   -- print("all abilities")
   -- for i, ability in ipairs(normalAbilities) do
   --    print(i, ability)
   -- end
   -- for i, ability in ipairs(ultimates) do
   --    print(i, ability)
   -- end

   -- Deal initial hand to each player.
   for _, team in ipairs(teams) do
      local playerCount = PlayerResource:GetPlayerCountForTeam(team)

      if playerCount ~= 0 then
	 for i = 1, playerCount do
	    local playerId = PlayerResource:GetNthPlayerIDOnTeam(team, i)
	    local hand = {}
	    
	    handsByPlayer[playerId] = hand
	    picksByPlayer[playerId] = {}

	    for a = 1, abilitiesPerHand do
	       hand["a" .. i] = dealCard(normalAbilities)
	    end

	    for u = 1, ultimatesPerHand do
	       hand["u" .. i] = dealCard(ultimates)
	    end

	    for h = 1, heroesPerHand do
	       hand["h" .. i] = dealCard(allHeroes)
	    end
	 end
      end
   end

   -- TODO: decide which things should be custom net tables
   -- then fire events to let the players know what hands they've been dealt.
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
      if canPickAbility(name, ability) then
	 if (ability["AbilityType"] == "DOTA_ABILITY_TYPE_ULTIMATE") then
	    table.insert(ultimates, name)
	 else
	    table.insert(normal, name)
	 end
      end
   end

   return {normal = normal, ultimates = ultimates}
end

function canPickAbility(name, ability)
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

function selectHeroAndAbilities(playerID)
   local hand = handsByPlayer(playerID)
   local player = PlayerResource:GetPlayer(playerID)

   CreateHeroForPlayer(hand["hero"], player)

   local hero = player:GetAssignedHero()

   -- Remove the player's default abilities.
   while hero.GetAbilityCount() > 0 do
      hero.removeAbility(
	 hero.getAbilityByIndex(1):GetAbilityName()
      )
   end

   -- Add the custom abilities they picked.
   for _, ability in ipairs(hand["abilities"]) do
      hero.addAbility(
	 ability
      )
   end

   -- TODO: add sub-abilities

   hero.addAbility(hand["ultimate"])
end
