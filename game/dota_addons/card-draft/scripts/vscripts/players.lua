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

   forEachPlayer(doTest)
   
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
