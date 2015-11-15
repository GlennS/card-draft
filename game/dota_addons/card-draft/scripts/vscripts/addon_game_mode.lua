-- Entry point

require("deal")

if CardDraftGameMode == nil then
   CardDraftGameMode = class({})
end

function Precache(context)
   PrecacheResource("model_folder", "models/courier/", context)
end

function Activate()
   GameRules.CardDraft = CardDraftGameMode()
   GameRules.CardDraft:InitGameMode()
end

function CardDraftGameMode:InitGameMode()
   ListenToGameEvent("game_rules_state_change", self.StateChange, nil)
   ListenToGameEvent('player_connect_full', self.OnConnectFull, nil)
end

function CardDraftGameMode:OnConnectFull()
   -- Force all players to be Abbadon
   GameRules:GetGameModeEntity():SetCustomGameForceHero("npc_dota_hero_abaddon")
end

function CardDraftGameMode:StateChange()
   local state = GameRules:State_Get()
   
   if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
      deal()
   
   elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
      draft()
   end
end
