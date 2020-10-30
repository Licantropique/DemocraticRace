local negotiation_defs = require "negotiation/negotiation_defs"
local CARD_FLAGS = negotiation_defs.CARD_FLAGS
local EVENT = negotiation_defs.EVENT

local CARDS = {
    assassin_fight_call_for_help = 
    {
        name = "Call For Help",
        desc = "Attempt to call for help and ask someone to deal with the assassin.",
        cost = 1,
        -- min_persuasion = 1,
        -- max_persuasion = 3,
        flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
        init_help_count = 1,

        OnPostResolve = function( self, minigame, targets )
            self.negotiator:AddModifier("CONNECTED_LINE", self.init_help_count)
        end,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() == DECK_TYPE.TRASH 
                    and self.negotiator:GetModifierStacks( "CONNECTED_LINE" ) <= 0 then
                    self.show_dealt = true
                    self:TransferCard(self.engine.hand_deck)
                end
            end,
        },
    },
    -- this is too boring.
    -- assassin_fight_describe_information = 
    -- {
    --     name = "Describe Situation",
    --     desc = "Discribe your current situation to the dispacher.\nIncrease the stacks of <b>Connected Line</> by 1.",
    --     cost = 1,
    --     -- min_persuasion = 1,
    --     -- max_persuasion = 3,
    --     flags = CARD_FLAGS.DIPLOMACY | CARD_FLAGS.STICKY,
    --     rarity = CARD_RARITY.UNIQUE,
    --     deck_handlers = ALL_DECKS,

    --     OnPostResolve = function( self, minigame, targets )
    --         if self.negotiator:GetModifierStacks( "CONNECTED_LINE" ) > 0 then
    --             self.negotiator:AddModifier("CONNECTED_LINE", 1)
    --         else
    --             minigame:ExpendCard(self)
    --         end
    --     end,
    --     event_handlers =
    --     {
    --         [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
    --             if card == self and target_deck and target_deck:GetDeckType() ~= DECK_TYPE.IN_HAND then
    --                 self.show_dealt = true
    --                 if self.negotiator:GetModifierStacks( "CONNECTED_LINE" ) > 0 then
    --                     local has_card = false
    --                     for k,v in pairs(self.engine:GetHandDeck().cards) do
    --                         if v.id == self.id and v ~= self then
    --                             has_card = true
    --                         end
    --                     end
    --                     if not has_card then
    --                         self:TransferCard(self.engine.hand_deck)
    --                     else
    --                         self:TransferCard(self.engine.trash_deck)
    --                     end
    --                 else
    --                     self:TransferCard(self.engine.trash_deck)
    --                 end
    --             end
    --         end,
    --     },
    -- },
    address_question = 
    {
        name = "Address Question",
        desc = "Target a question argument. Resolve the effect based on the question being addressed. "..
            "Remove the argument afterwards.\nIf this card leaves the hand, {EXPEND} it.",
        loc_strings = {
            NOT_A_QUESTION = "Target is not a question",
        },
        cost = 1,
        flags = CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNIQUE,
        target_enemy = TARGET_FLAG.ARGUMENT | TARGET_FLAG.BOUNTY,
        deck_handlers = ALL_DECKS,
        event_handlers =
        {
            [ EVENT.CARD_MOVED ] = function( self, card, source_deck, source_idx, target_deck, target_idx )
                if card == self and target_deck and target_deck:GetDeckType() ~= DECK_TYPE.IN_HAND then
                    self:TransferCard(self.engine.trash_deck)
                end
            end,
        },
        CanTarget = function(self, target)
            if is_instance( target, Negotiation.Modifier ) and target.AddressQuestion then
                return true
            end
            return false, self.def:GetLocalizedString("NOT_A_QUESTION")
        end,
        OnPostResolve = function( self, minigame, targets )
            for i, target in ipairs(targets) do
                if is_instance( target, Negotiation.Modifier ) and target.AddressQuestion then
                    target:AddressQuestion()
                    target:GetNegotiator():RemoveModifier( target )
                end
            end
        end,
    },
    question_answer = 
    {
        name = "Question answer",
        name_fn = function(self, fmt_str)
            -- print("wololo")
            -- print(self.issue_data)
            -- print(self.stance)
            if self.issue_data and self.stance then
                -- print("narvini")
                return self.issue_data.stances[self.stance]:GetLocalizedName()
            end
            return loc.format(fmt_str)
        end,
        desc = "This is a place that describes the answer to a question.",
        desc_fn = function(self, fmt_str)
            if self.issue_data and self.stance then
                if CheckBits( self.flags, CARD_FLAGS.HOSTILE ) then
                    -- there's no need to localize the following because it's only identifiers
                    return "{CHANGING_STANCE}\n" .. self.issue_data.stances[self.stance]:GetLocalizedDesc()
                else
                    return self.issue_data.stances[self.stance]:GetLocalizedDesc()
                end
            end
            return loc.format(fmt_str)
        end,
        flavour = "Here's what I think...",
        loc_strings = {
            ISSUE_DESC = "About <b>{1}</>:\n{2}",
        },
        flavour_fn = function(self, fmt_str)
            if self.issue_data then
                return loc.format(self.def:GetLocalizedString("ISSUE_DESC"), self.issue_data.name, self.issue_data.desc)
            end
            return loc.format(fmt_str)
        end,
        -- hide_in_cardex = true,
        manual_desc = true,

        cost = 0,
        flags = CARD_FLAGS.UNPLAYABLE | CARD_FLAGS.DIPLOMACY,
        rarity = CARD_RARITY.UNIQUE,

        UpdateIssue = function(self, issue_data, stance)
            self.issue_data = issue_data
            self.stance = stance

            local old_stance = DemocracyUtil.TryMainQuestFn("GetStance", issue_data )

            if old_stance and self.stance ~= old_stance then
                ClearBits( self.flags, CARD_FLAGS.DIPLOMACY )
                SetBits( self.flags, CARD_FLAGS.HOSTILE )
            end

            self.engine:BroadcastEvent( EVENT.CARD_CHANGED, self, self:Clone() )
        end,
    },
    
    contemporary_question_card =
    {

        flags = CARD_FLAGS.SPECIAL | CARD_FLAGS.OPPONENT,
        cost = 0,
        stacks = 1,
        rarity = CARD_RARITY.UNIQUE,

        series = CARD_SERIES.NPC,

        CanPlayCard = function( self, card, engine, target )
            if card == self then
                if not table.arraycontains(self.negotiator.behaviour.available_issues, self.issue_data) then
                    self.issue_data = nil
                end
                if self.issue_data then
                    return true
                else
                    self:TrySelectIssue()
                    return self.issue_data ~= nil
                end
            end
            return true
        end,
        TrySelectIssue = function(self)
            if self.negotiator and self.negotiator.behaviour.available_issues then
                self.issue_data = table.arraypick(self.negotiator.behaviour.available_issues)
            end
        end,

        OnPostResolve = function( self, engine, targets )
            local modifier = self.negotiator:CreateModifier("CONTEMPORARY_QUESTION")
            if modifier then
                modifier:SetIssue(self.issue_data)
            end
            if self.issue_data and self.negotiator.behaviour.available_issues then
                table.arrayremove(self.negotiator.behaviour.available_issues, self.issue_data)
                self.issue_data = nil
            end
        end,
    },

    propaganda_poster = 
    {
        name = "Propaganda Poster",
        desc = "{IMPRINT}\nCreate a {{1}} {PROPAGANDA_POSTER_MODIFIER} with the cards imprinted on this card.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.prop_mod or "PROP_PO_MEDIOCRE")
        end,
        
        flavour = "Imprinted Cards:\n{1}",
        flavour_fn = function( self, fmt_str )
            if self == nil then
                return ""
            else
                if self.userdata.imprints then
                    local res = ""
                    for i, card in ipairs(self.userdata.imprints) do
                        res = res .. loc.format("{1#card}\n", card)
                    end
                    return loc.format(fmt_str, res)
                end
                return ""
            end
        end,
        
        cost = 2,
        max_charges = 3,
        flags = CARD_FLAGS.ITEM | CARD_FLAGS.EXPEND,
        rarity = CARD_RARITY.UNIQUE,
    }
}
for id, def in pairs( CARDS ) do
    if not def.series then
        def.series = CARD_SERIES.GENERAL
    end
    Content.AddNegotiationCard( id, def )
end

local FEATURES = {
    CHANGING_STANCE = 
    {
        name = "Changing Stance",
        desc = "You have already taken a stance on this issue. Changing it may make people think you're hypocritical, and you might lose support!",
    },
    IMPRINT =
    {
        name = "Imprint",
        desc = "Some cards are imprinted on this object through special means, and they will affect the behaviour of this object.",
    },
}
for id, data in pairs(FEATURES) do
	local def = NegotiationFeatureDef(id, data)
	Content.AddNegotiationCardFeature(id, def)
end