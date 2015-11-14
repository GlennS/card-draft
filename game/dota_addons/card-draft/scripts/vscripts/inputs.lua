-- TODO: we'd prefer not to have to distribute the npc_heroes.txt and npc_abilities.txt files ourselves - is there some better way?
function loadHeroes()
   -- Returns a list of all the heroes in Dota 2.
   local heroes = LoadKeyValues("scripts/data/npc_heroes.txt")
   -- See Unavailable Heroes in http://dota2.gamepedia.com/Game_modes#Ability_Draft
   forbiddenHeroes = {
      "npc_dota_hero_base",
      "Version",
      "npc_dota_hero_beastmaster",
      "npc_dota_hero_chen",
      "npc_dota_hero_doom_bringer",
      "npc_dota_hero_earth_spirit",
      "npc_dota_hero_ember_spirit",
      "npc_dota_hero_keeper_of_the_light",
      "npc_dota_hero_morphling",
      "npc_dota_hero_phoenix",
      "npc_dota_hero_puck",
      "npc_dota_hero_rubick",
      "npc_dota_hero_nevermore",
      "npc_dota_hero_spectre",
      "npc_dota_hero_shadow_demon",
      "npc_dota_hero_techies",
      "npc_dota_hero_templar_assassin",
      "npc_dota_hero_shredder",
      "npc_dota_hero_troll_warlord",
      "npc_dota_hero_tusk",
      "npc_dota_hero_invoker",
      "npc_dota_hero_abyssal_underlord",
      "npc_dota_hero_lone_druid",
      "npc_dota_hero_ogre_magi",
      "npc_dota_hero_meepo"
   }
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
      -- Brewmaster primal split elemental abilities
      "brewmaster_earth_hurl_boulder",
      "brewmaster_earth_spell_immunity",
      "brewmaster_earth_pulverize",
      "brewmaster_storm_dispel_magic",
      "brewmaster_storm_cyclone",
      "brewmaster_storm_wind_walk",
      "brewmaster_fire_permanent_immolation",
      -- Lycan's wolves' abilities
      "lycan_summon_wolves_critical_strike",
      "lycan_summon_wolves_invisibility",
      -- Warlock's golem's abilities
      "warlock_golem_flaming_fists",
      "warlock_golem_permanent_immolation",
      -- Transformed dragon knight ability
      "dragon_knight_frost_breath",
      -- This slipts though because it's prefixed by the hero name 'centaur'.
      "centaur_khan_war_stomp"
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
