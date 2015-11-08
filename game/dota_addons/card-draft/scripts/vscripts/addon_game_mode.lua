-- Entry point

require("deal")

if CardDraftGameMode == nil then
   CardDraftGameMode = class({})
end

function Precache(context)
end

function Activate()
   GameRules.CardDraft = CardDraftGameMode()
   GameRules.CardDraft:InitGameMode()
end

function CardDraftGameMode:InitGameMode()
   ListenToGameEvent("game_rules_state_change", self.StateChange, nil)
end

function CardDraftGameMode:StateChange()
   if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
      deal()
   end
end
