"use strict";

/*global $*/

(function() {
    var ability = "ability",
	ultimate = "ultimate",
	hero = "hero",

	cardsContainer = $("#cards"),
	picksContainer = $("#confirmed-picks"),
	
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
	};

    var showHand = function(hand) {
	// Remove last round's cards.
	cardsContainer.RemoveAndDeleteChildren();
	
	var cardElements = [];

	// Add each card in our new hand.
	Object.keys(hand).forEach(function(k) {
	    var card = hand[k];

	    var cardEl = $.CreatePanel("Button", cardsContainer, "");
	    cardEl.AddClass("card");
	    cardEl.AddClass(card.type + "-card");
	    cardEl.enabled = isAvailable(card);

	    cardElements.push(cardEl);

	    cardEl.SetPanelEvent("onactivate", function() {
		/*
		  Can only activate one card from each hand.
		*/
		cardElements.forEach(function(otherCardEl) {
		    otherCardEl.enabled = false;
		});

		pick(card);		
	    });
	    
	    var image = imageTypes[card.type](cardEl, card.name);
	});
    },

	pick = function(card) {
	    // Tell the server what we want.
	    GameEvents.SendCustomGameEventToServer("player-drafted-card", card);

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
	};

    GameEvents.Subscribe("player-passed-hand", showHand);
    GameEvents.SendCustomGameEventToServer("panorama-js-ready", {});
    // TODO: timer
    // TODO: listen for new pick events (in case we randomed).
}());
