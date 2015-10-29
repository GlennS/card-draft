abilities = 4
ultimates = 2
heroes = 1

function deal()
   print("Entering deal")
   
   -- Pause to prevent standard hero picking from happening.
   PauseGame(true)

   -- Load all possible options.
   local allHeroes = loadHeroes()
   local allAbilities = loadAbilities(allHeroes)
   local normalAbilities = allAbilities["normal"]
   local ultimates = allAbilities["ultimates"]

   handsByPlayer = {}
   picksByPlayer = {}

   function dealCard(list)
      -- Randomly pick from the list of ultimates.
      local i = math.random(#list)
      local dealt = list[i]

      list:remove(i)
      
      return dealt
   end

   local teams = {DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}

   -- Deal initial hand to each player.
   for _, team in ipairs(teams) do
      local playerCount = PlayerResource:GetPlayerCountForTeam(team)
      if playerCount ~= 0 then
	 for i = 1, playerCount do
	    local playerId = PlayerResource:GetNthPlayerIDOnTeam(team, i)
	    local hand = {}
	    
	    handsByPlayer[playerId] = hand
	    picksByPlayer[playerId] = {}

	    for a = 1, abilities do
	       hand["a" .. i] = dealCard(normalAbilities)
	    end

	    for u = 1, ultimates do
	       hand["u" .. i] = dealCard(ultimates)
	    end

	    for h = 1, heroes do
	       hand["h" .. i] = dealCard(heroes)
	    end
	 end
      end
   end

   print("all heroes")
   for i, hero in ipairs(allHeroes) do
      print("hero", i, hero)
   end

   print("all abilities")
   for i, ability in ipairs(allAbilities) do
      print("abilities", i, ability)
   end

   -- TODO: decide which things should be custom net tables
   -- then fire events to let the players know what hands they've been dealt.
end

function loadHeroes()
   -- Returns a list of all the heroes in Dota 2.
   -- TODO: can we use the dota_npc_units.txt file?
   return LoadKeyValues("scripts/data/heroes.txt")["heroes"]
end

function loadAbilities(heroes)
   -- Given a list of heroes, returns the names of their abilities, divided into normal and ultimate abilities.

   local normal = {}
   local ultimates = {}

   for i, heroname in ipairs(allHeroes) do
      -- TODO: Create the hero temporarily in order to enumerate its abilities.
      local hero = CreateUnitByName(heroname, vLocation, true, hNPCOwner, hUnitOwner, 1)

      for i, hero in GetAbilityCount() do
	 local ability = hero:GetAbilityByIndex(i)

	 if ability:GetHeroLevelRequiredToUpgrade() > 1 then
	    ultimates[#ultimates + 1] = ability:GetAbilityName()
	 else
	    normal[#normal + 1] = ability:GetAbilityName()
	 end
      end

      hero:RemoveSelf()
   end

   return {normal = normal, ultimates = ultimates}
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

   hero.addAbility(hand["ultimate"])
end
