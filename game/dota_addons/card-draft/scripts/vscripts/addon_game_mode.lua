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
   GameRules:SetHeroSelectionTime(0)
   ListenToGameEvent("game_rules_state_change", self.StateChange, nil)
end

function CardDraftGameMode:StateChange()
   if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
      deal()
   elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
      assignAllHeroes()
   end
end
