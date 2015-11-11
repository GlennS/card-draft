-- TODO: we'd prefer not to have to distribute the npc_heroes.txt and npc_abilities.txt files ourselves - is there some better way?
function loadHeroes()
   -- Returns a list of all the heroes in Dota 2.
   local heroes = LoadKeyValues("scripts/data/npc_heroes.txt")
   forbiddenHeroes = {"npc_dota_hero_base", "Version", "npc_dota_hero_invoker", "npc_dota_hero_abyssal_underlord"}
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

function loadAbilities(heroNames)
   -- Returns a list of all the abilities in Dota 2, divided up by whether they are an ultimate or normal skill.
   local normal = {}
   local ultimates = {}

   local abilities = LoadKeyValues("scripts/data/npc_abilities.txt")

   for name, ability in pairs(abilities) do
      if isPickableAbility(name, ability) and isHeroAbility(name, heroNames) then
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
   local forbiddenNames = {
      "Version",
      "ability_base",
      "lone_druid_spirit_bear_return",
      "lone_druid_spirit_bear_demolish",
      "lone_druid_spirit_bear_entangle"
   }

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

local heroNamePrefix = "npc_dota_hero_"
local heroNamePrefixLength = string.len(heroNamePrefix)

-- Tests whether an ability belongs to a hero.
-- Does this by checking whether it contains that hero's name.
function isHeroAbility(abilityName, heroNames)
   for _, heroName in ipairs(heroNames) do
      heroName = string.sub(heroName, heroNamePrefixLength + 1)
      
      if string.starts(abilityName, heroName) then
	 return true
      end
   end

   return false
end

-- See http://lua-users.org/wiki/StringRecipes
function string.starts(str, start)
   return string.sub(
      str, 1, string.len(start)
   ) == start
end
