"use strict";

/*global $, GameEvents*/

(function() {
    var ability = "ability",
	ultimate = "ultimate",
	hero = "hero",

	message = "",
	messages = {
	    welcome: "welcome-to-draft",
	    draftTimeRemaining: "draft-time-remaining",
	    intermissionTimeRemaining: "intermission-time-remaining",
	    player: "player-pick",
	    forced: "forced-pick",
	    random: "random-pick",
	    noChoices: "cannot-pick",
	    ready: "ready-for-pick"
	},

	setMessage = function(newMessage, cardName) {
	    message = newMessage;
	    if (cardName) {
		message += ' ' + $.Localize('#' + cardName);
	    }
	    
	    roundTimer.text = message;
	},

	cardsContainer = $("#cards"),
	picksContainer = $("#confirmed-picks"),
	roundTimer = $("#timer-text"),
	
	dummyHand = [
	    {type: ability, name: "antimage_blink" },
	    {type: ability, name: "axe_berserkers_call"},
	    {type: ability, name: "bane_enfeeble"},
	    {type: ability, name: "bloodseeker_bloodrage"},
	    {type: ultimate, name: "bloodseeker_rupture"},
	    {type: ultimate, name: "drow_ranger_marksmanship"},
	    {type: hero, name: "npc_dota_hero_axe"}
	],

	limits = {
	    hero: 1,
	    ultimate: 1,
	    ability: 3
	},

	abilityImage = function(parent, name) {
	    var el = $.CreatePanel("DOTAAbilityImage", parent, "");
	    el.abilityname = name;

	    el.SetPanelEvent("onmouseover", function() {
		$.DispatchEvent("DOTAShowAbilityTooltip", el, name);
	    });
	    
	    el.SetPanelEvent("onmouseout", function() {
		$.DispatchEvent("DOTAHideAbilityTooltip", el);
	    });

	    return el;
	},

	imageTypes = {
	    hero: function(parent, name) {
		var el = $.CreatePanel("DOTAHeroImage", parent, "");
		el.heroname = name;
		el.heroimagestyle = "portrait";

		el.SetPanelEvent("onmouseover", function() {
		    $.DispatchEvent("DOTAShowTextTooltip", $.Localize("#" + name));
		});
		
		el.SetPanelEvent("onmouseout", function() {
		    $.DispatchEvent("DOTAHideTextTooltip", el);
		});
		
		return el;
	    },
	    ultimate: abilityImage,
	    ability: abilityImage
	},

	picked = {
	    hero: [],
	    ultimate: [],
	    ability: []
	},

	cardElements = [],

	showHand = function(hand) {
	    var anyPicks = false;
	    
	    // Remove last round's cards.
	    cardsContainer.RemoveAndDeleteChildren();
	    
	    // Add each card in our new hand.
	    Object.keys(hand).forEach(function(k) {
		var card = hand[k];

		var cardEl = $.CreatePanel("Button", cardsContainer, "");
		cardEl.AddClass("card");
		cardEl.AddClass(card.type + "-card");
		cardEl.AddClass(card.name);
		cardEl.enabled = isAvailable(card);

		anyPicks = anyPicks || cardEl.enabled;

		cardElements.push(cardEl);

		cardEl.SetPanelEvent("onactivate", function() {
		    playerPicked(card);		
		});
		
		var image = imageTypes[card.type](cardEl, card.name);
	    });

	    if (anyPicks) {
		setMessage(messages.ready);
	    } else {
		setMessage(messages.noChoices);
	    }
	},

	playerPicked = function(card) {
	    setMessage(messages.player, card.name);
	    
	    updateUIToReflectPick(card);
	    
	    // Tell the server what we want.
	    GameEvents.SendCustomGameEventToServer("player-drafted-card", card);
	},

	alreadyPicked = function(card) {
	    var sawCard = false;
	    
	    picked[card["type"]].forEach(function(pick) {
		if (card["name"] == pick["name"]) {
		    sawCard = true;
		}
	    });

	    return sawCard;
	},

	updateUIToReflectPick = function(card) {
	    if (alreadyPicked(card)) {
		return;
	    }

	    if (card.reason) {
		setMessage(messages[card.reason], card.name);
	    }

	    /*
	     Prevent activating any further cards from that hand.
	     */
	    cardElements.forEach(function(otherCardEl) {
		try {
	    	    otherCardEl.enabled = false;
		} catch (e) {
		    // No-op, the card probably no longer exists.
		}
	    });

	    // Keep a record of what we chose.
	    picked[card.type].push(card);

	    // Display the pick to the player.
	    imageTypes[card.type](picksContainer, card.name);
	},

	isAvailable = function(card) {
	    var needed = limits[card.type];

	    if (picked[card.type]) {
		needed -= picked[card.type].length;
	    }

	    return needed > 0;
	},

	updateRoundTimer = function(timer) {
	    roundTimer.text = message
		+ '\n'
		+ messages[timer.phase + "TimeRemaining"]
		+ timer.value;
	};

    Object.keys(messages).forEach(function(m) {
	messages[m] = $.Localize('#' + messages[m]);
    });

    setMessage(messages.welcome);
    
    GameEvents.Subscribe("player-passed-hand", showHand);
    
    // Listen for new pick events (in case we were forced to pick a card because we ran out of time, or it was the only option).
    GameEvents.Subscribe("player-pick-confirmed", updateUIToReflectPick);

    GameEvents.Subscribe("round-timer-count", updateRoundTimer);

    GameEvents.SendCustomGameEventToServer("panorama-js-ready", {});
}());
