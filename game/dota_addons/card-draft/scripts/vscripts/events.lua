require("players")

function listenToPlayerEvent(event, eventHandler)
   CustomGameEventManager:RegisterListener(
      event,
      function(entityIndex, data)
	 eventHandler(
	    -- This is magically made available, yay.
	    data["PlayerID"],
	    data
	 )
      end
   )
end

-- Waits for all players to send the event 'panorama-js-ready' back from their client, and then runs 'f'.
-- This event should usually be sent as the last thing the clients do.
function waitForAllPlayers(f)
   local waiting = {}
   
   forEachPlayer(
      function(playerId)
	 table.insert(waiting, playerId)
      end
   )

   listenToPlayerEvent(
      "panorama-js-ready",
      function(playerId, data)
	 local playerIndex = nil

	 for i, waitingPlayerId in ipairs(waiting) do
	    if playerId == waitingPlayerId then
	       playerIndex = i
	    end
	 end

	 if playerIndex == nil then
	    -- No-op
	 else
	    table.remove(waiting, playerIndex)
	    if #waiting == 0 then
	       f()
	    end
	 end
      end
   )
   
end
