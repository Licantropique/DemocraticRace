local negotiation_defs = require "negotiation/negotiation_defs"
local CARD_FLAGS = negotiation_defs.CARD_FLAGS
local EVENT = negotiation_defs.EVENT

local ALLY_IMAGES = {
    RISE_AUTOMECH = engine.asset.Texture( "negotiation/modifiers/recruit_rise_cobblebot.tex"),
    RISE_AUTODOG = engine.asset.Texture( "negotiation/modifiers/recruit_rise_cobbledog.tex"),
    RISE_RADICAL = engine.asset.Texture( "negotiation/modifiers/recruit_rise_radical.tex"),
    RISE_REBEL = engine.asset.Texture( "negotiation/modifiers/recruit_rise_rebel.tex"),
    RISE_PAMPLETEER = engine.asset.Texture( "negotiation/modifiers/recruit_rise_pamphleteer.tex"),
    SPARK_BARON_AUTOMECH = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_automech.tex"),
    AUTODOG = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_autodog.tex"),
    SPARK_BARON_PROFESSIONAL = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_professional.tex"),
    SPARK_BARON_GOON = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_goon.tex"),
    SPARK_BARON_TASKMASTER = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_taskmaster.tex"),
    COMBAT_DRONE = engine.asset.Texture( "negotiation/modifiers/recruit_spark_baron_drone.tex"),
    
    VROC = engine.asset.Texture( "negotiation/modifiers/recruit_admiralty_vroc.tex"),
    ADMIRALTY_CLERK = engine.asset.Texture( "negotiation/modifiers/recruit_admiralty_clerk.tex"),
    ADMIRALTY_GOON = engine.asset.Texture( "negotiation/modifiers/recruit_admiralty_goon.tex"),
    ADMIRALTY_GUARD = engine.asset.Texture( "negotiation/modifiers/recruit_admiralty_guard.tex"),
    ADMIRALTY_PATROL_LEADER = engine.asset.Texture( "negotiation/modifiers/recruit_admiralty_patrol_leader.tex"),
    JAKES_RUNNER = engine.asset.Texture( "negotiation/modifiers/recruit_jake_runner.tex"),
    WEALTHY_MERCHANT = engine.asset.Texture( "negotiation/modifiers/recruit_civilian_wealthy_merchant.tex"),
    HEAVY_LABORER = engine.asset.Texture( "negotiation/modifiers/recruit_civilian_heavy_laborer.tex"),
}

local function CreateNewSelfMod(self)
    local newmod = self.negotiator:CreateModifier(self.id, self.stacks, self)
    if newmod then
        newmod.generation = (self.generation or 0) + 1
        newmod.init_max_resolve = self.init_max_resolve
        if newmod.OnInit then
            newmod:OnInit()
        end
    end
end
local function CalculateBonusScale(self)
    if self.bonus_scale and type(self.bonus_scale) == "table" then
        if self.engine and CheckBits(self.engine:GetFlags(), NEGOTIATION_FLAGS.WORDSMITH) then
            return self.bonus_scale[ 
                math.min( GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1,
                #self.bonus_scale) 
            ]
        else
            return self.bonus_scale[1]
        end
    end
    return self.bonus_per_generation
end
local function MyriadInit(self)
    self.bonus_per_generation = CalculateBonusScale(self)
    if self.generation and self.generation > 0 then
        self.init_max_resolve = self.init_max_resolve + self.bonus_per_generation
    end
    self:SetResolve(self.init_max_resolve)
end

local MODIFIERS =
{
    PLAYER_ADVANTAGE =
    {
        name = "Limited Time",
        desc = "The player wins after the opponent's turn {1}, but will yield worse result than winning a negotiation normally.",
        icon = "DEMOCRATICRACE:assets/modifiers/player_advantage.png",
        desc_fn = function( self, fmt_str )
            return loc.format(fmt_str, self.stacks or 1)
        end,
        modifier_type = MODIFIER_TYPE.PERMANENT,
        -- win_on_turn = 7,
        event_handlers = {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                if minigame:GetTurns() > (self.stacks or 1) then
                    minigame:Win()
                    minigame.impasse = true
                end
                
            end,
        },
    },
    PREACH_CROWD =
    {
        name = "Crowd Mentality",
        desc = "At the beginning of the player's turn, create a new <b>Potential Interest</> argument({1} left).",
        desc_fn = function(self, fmt_str )

            return loc.format(fmt_str, #self.agents)
        end,
        icon = "negotiation/modifiers/heckler.tex",
        modifier_type = MODIFIER_TYPE.CORE,
        agents = {},
        ignored_agents = {},
        CreateTarget = function(self, agent)
            local modifier = Negotiation.Modifier("PREACH_TARGET_INTEREST", self.negotiator) 
            modifier:SetAgent(agent)
            self.negotiator:CreateModifier(modifier)
        end,
        TryCreateNewTarget = function(self)
            if self.agents and #self.agents > 0 then
                self:CreateTarget(self.agents[1])
                table.remove(self.agents, 1)
                return true
            end
            return false
        end,
        event_priorities =
        {
            [ EVENT.BEGIN_PLAYER_TURN ] = 999,
        },
        event_handlers = {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                if minigame.turns > 1 then
                    -- for i = 1, math.floor(self.engine:GetDifficulty() / 3 + 1) do
                        self:TryCreateNewTarget()
                    -- end
                end
                if #self.agents == 0 and self.negotiator:GetModifierInstances( "PREACH_TARGET_INTEREST" ) == 0 then
                    minigame:Win()
                end
            end,
        },
        InitModifiers = function(self)
            self.ignored_agents = {}
            for i = 1, 2 + math.floor(self.engine:GetDifficulty() / 2) do
                self:TryCreateNewTarget()
            end
        end,
    },
    PREACH_TARGET_INTEREST = 
    {
        name = "Potential Interest",
        desc = "Each turn, this argument attacks an opponent argument or gain resolve.\n\n" ..
            "Destroy this argument to convince <b>{1.fullname}</> to join your side.\n\n"..
            "After {2} {2*turn|turns}, this argument removes itself. <#PENALTY>When this happens, if "..
            "this argument has more than {4} resolve, {1.name} will become annoyed and dislike you.</>",
        loc_strings = {
            BONUS_LOVED = "<#BONUS><b>{1.name} loves you.</> {3} max resolve.</>",
            BONUS_LIKED = "<#BONUS><b>{1.name} likes you.</> {3} max resolve.</>",
            BONUS_DISLIKED = "<#PENALTY><b>{1.name} dislikes you.</> +{3} max resolve.</>",
            BONUS_HATED = "<#PENALTY><b>{1.name} hates you.</> +{3} max resolve.</>",
            BONUS_BRIBED = "<#BONUS><b>{1.name} is bribed.</> {2} max resolve.</>",
        },
        delta_max_resolve = {
            [RELATIONSHIP.LOVED] = -8,
            [RELATIONSHIP.LIKED] = -4,
            [RELATIONSHIP.DISLIKED] = 4,
            [RELATIONSHIP.HATED] = 8,
        },
        bribe_delta = -4,
        key_maps = {
            [RELATIONSHIP.LOVED] = "BONUS_LOVED",
            [RELATIONSHIP.LIKED] = "BONUS_LIKED",
            [RELATIONSHIP.DISLIKED] = "BONUS_DISLIKED",
            [RELATIONSHIP.HATED] = "BONUS_HATED",
        },
        desc_fn = function( self, fmt_str, minigame, widget )
            if self.target_agent and widget and widget.PostPortrait then
                --local txt = loc.format( "{1#agent} is not ready to fight!", self.ally_agent )
                widget:PostPortrait( self.target_agent )
            end
            local resultstring = ""
            if self.target_agent then
                if self.key_maps[self.target_agent:GetRelationship()] then
                    resultstring = self.def:GetLocalizedString(self.key_maps[self.target_agent:GetRelationship()])
                end
                if self.target_agent:HasAspect("bribed") then
                    resultstring = resultstring .. "\n" .. loc.format(self.def:GetLocalizedString("BONUS_BRIBED"), self.target_agent, self.bribe_delta)
                end
            end
            resultstring = resultstring .. "\n\n" .. fmt_str
            print(resultstring)
            return loc.format(resultstring, self.target_agent and self.target_agent:LocTable(), 
                self.stacks, self.delta_max_resolve[self.target_agent:GetRelationship()], self.annoyed_threshold or 12)
            -- else 
            --     return loc.format(fmt_str, self.target_agent and self.target_agent:LocTable(), self.stacks)
            -- end
            
        end,
        no_damage_tt = true,
        icon = engine.asset.Texture("negotiation/modifiers/voice_of_the_people.tex"),

        target_enemy = TARGET_ANY_RESOLVE,
        composure_gain = 2,
        modifier_type = MODIFIER_TYPE.ARGUMENT,

        -- turns_left = 3,
        is_first_turn = true,
    
        SetAgent = function (self, agent)
            local difficulty = self.engine and self.engine:GetDifficulty() or 1
            self.target_agent = agent
            self.max_resolve = difficulty * 5 + 7
            self.annoyed_threshold = self.max_resolve - (difficulty) * 4
            self.annoyed_threshold = math.max(1, self.annoyed_threshold)
            if agent:HasAspect("bribed") then
                self.max_resolve = self.max_resolve + self.bribe_delta
            end
            self.max_resolve = math.max(1, self.max_resolve + (self.delta_max_resolve[agent:GetRelationship()] or 0))
          --  self.min_persuasion = 2 + agent:GetRenown()
            --self.max_persuasion = self.min_persuasion + 4
            self:SetResolve(math.max(self.max_resolve, 1))

            self.annoyed_threshold = math.min(self.max_resolve, math.floor((self.max_resolve + self.annoyed_threshold) / 2))
            
            self.min_persuasion = math.floor((difficulty - 1) / 2)
            self.max_persuasion = 2 + math.floor(difficulty / 2)

            if agent:GetRelationship() > RELATIONSHIP.NEUTRAL then
                self.max_persuasion = self.max_persuasion - 1
            elseif agent:GetRelationship() < RELATIONSHIP.NEUTRAL then
                self.max_persuasion = self.max_persuasion + 1
            end
            
            if agent:HasAspect("bribed") then
                self.max_persuasion = self.max_persuasion - 1
            end

            -- ensures max_persuasion is greater than min_persuasion
            self.max_persuasion = math.max(self.min_persuasion, self.max_persuasion)

            if ALLY_IMAGES[agent:GetContentID()] then
                self.icon = ALLY_IMAGES[agent:GetContentID()]
                self.engine:BroadcastEvent( EVENT.UPDATE_MODIFIER_ICON, self)
                -- self:NotifyTriggered()
            end
            self.stacks = 3
            
            self:NotifyChanged()
        end,

        OnBounty = function(self, source)
            if source and source ~= self then
                local modifier = Negotiation.Modifier( "PREACH_TARGET_INTERESTED", self.anti_negotiator )
                if modifier and modifier.SetAgent then
                    modifier:SetAgent(self.target_agent)
                end
                self.anti_negotiator:CreateModifier( modifier )
            end
        end,

        OnEndTurn = function( self, minigame )
            if self.target_enemy then
                self:ApplyPersuasion()
            end
        end,

        event_handlers = {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                if not self.is_first_turn then
                    self.negotiator:RemoveModifier(self, 1)
                    -- self.turns_left = self.turns_left - 1
                    if self.stacks <= 0 then
                        local core = self.negotiator:FindCoreArgument()
                        if core and core.ignored_agents then
                            if self.resolve > self.annoyed_threshold then
                                table.insert(core.ignored_agents, self.target_agent)
                            end
                        end
                        -- self.negotiator:RemoveModifier(self)
                    end
                    -- self:NotifyChanged()
                end
                if self.stacks > 0 then
                    self.target_enemy = math.random() < 0.5 and TARGET_ANY_RESOLVE or nil
                    if not self.target_enemy then
                        self:DeltaComposure(self.composure_gain, self)
                    end
                end
            end,
            [ EVENT.END_TURN ] = function( self, minigame, negotiator )
                self.is_first_turn = false
            end,
        },
    },
    PREACH_TARGET_INTERESTED =
    {
        name = "Interested Target",
        desc = "{1.fullname} is interested in your ideology! Protect this argument until the end of the negotiation.",
        desc_fn = function( self, fmt_str, minigame, widget )
            if self.target_agent and widget and widget.PostPortrait then
                --local txt = loc.format( "{1#agent} is not ready to fight!", self.ally_agent )
                widget:PostPortrait( self.target_agent )
            end
            return loc.format(fmt_str, self.target_agent and self.target_agent:LocTable())
        end,

        target_enemy = TARGET_ANY_RESOLVE,
        modifier_type = MODIFIER_TYPE.BOUNTY,

        icon = engine.asset.Texture("negotiation/modifiers/voice_of_the_people.tex"),

        SetAgent = function (self, agent)
            self.target_agent = agent
            self.max_resolve = 4
          --  self.min_persuasion = 2 + agent:GetRenown()
            --self.max_persuasion = self.min_persuasion + 4
            self:SetResolve(self.max_resolve, MODIFIER_SCALING.LOW)
    
            self.min_persuasion = 0
            self.max_persuasion = 2

            if agent:GetRelationship() > RELATIONSHIP.NEUTRAL then
                self.max_persuasion = self.max_persuasion + 1
            elseif agent:GetRelationship() < RELATIONSHIP.NEUTRAL then
                self.max_persuasion = self.max_persuasion - 1
            end
            
            if agent:HasAspect("bribed") then
                self.max_persuasion = self.max_persuasion + 1
            end
            if ALLY_IMAGES[agent:GetContentID()] then
                self.icon = ALLY_IMAGES[agent:GetContentID()]
                self.engine:BroadcastEvent( EVENT.UPDATE_MODIFIER_ICON, self)
                -- self:NotifyTriggered()
            end
            self:NotifyChanged()
        end,
        OnEndTurn = function( self, minigame )
            self:ApplyPersuasion()
        end,
    },
    CONNECTED_LINE =
    {
        name = "Connected Line",
        -- Me wall of text
        desc = "Reach {1} stacks for the help to be sent. <#PENALTY>The opponent will also "..
            "gain 1 {IMPATIENCE} when that happens.</>\n\n"..
            "Gain 1 stack at the beginning of each turn.\n\n"..
            "<#PENALTY>If this gets destroyed, the opponent gains 1 {IMPATIENCE}, and you need to play "..
            "Call For Help again!</>",
        
        desc_fn = function(self, fmt_str, minigame, widget)
            -- if self.ally_agent and widget and widget.PostPortrait then
            --     --local txt = loc.format( "{1#agent} is not ready to fight!", self.ally_agent )
            --     widget:PostPortrait( self.ally_agent )
            -- end
            return loc.format( fmt_str, self.calls_required )
            -- return loc.format( fmt_str, self.ally_agent and self.ally_agent:LocTable(), self.negotiator and self.negotiator.agent:LocTable() )
        end,

        icon = "DEMOCRATICRACE:assets/modifiers/connected_line.png",

        calls_required = 5,
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 3,
        max_stacks = 10,

        -- force_target = true,

        -- OnInit = function(self)
            
        -- end,

        -- CanPlayCard = function( self, source, engine, target )
        --     if source:IsAttack() and target:GetNegotiator() == self.negotiator then
        --         if source.modifier_type == MODIFIER_TYPE.INCEPTION or source:GetNegotiator() ~= self.negotiator then
        --             if not target.force_target then
        --                 return false, loc.format( "Must target <b>{1}</b>", self:GetName() )
        --             end
        --         end
        --     end

        --     return true
        -- end,

        CleanUpCard = function(self, card_id)
            local to_expend = {}
            for i,card in self.engine:GetHandDeck():Cards() do
                if card.id == card_id then
                    table.insert(to_expend, card)
                end
            end
            for i,card in self.engine:GetDrawDeck():Cards() do
                if card.id == card_id then
                    table.insert(to_expend, card)
                end
            end
            for i,card in self.engine:GetDiscardDeck():Cards() do
                if card.id == card_id then
                    table.insert(to_expend, card)
                end
            end

            if #to_expend > 0 then
                for i,card in ipairs(to_expend) do
                    self.engine:ExpendCard(card)
                end
            end
        end,
        OnBounty = function(self, source)
            if source ~= self then  
                self.anti_negotiator:AddModifier("IMPATIENCE", 1)

                local card = Negotiation.Card( "assassin_fight_call_for_help", self.engine:GetPlayer() )
                if self.stacks > 1 then
                    card.init_help_count = self.stacks
                end
                self.engine:DealCard(card, self.engine:GetDiscardDeck())
            end

            -- self:CleanUpCard("assassin_fight_describe_information")
        end,
        event_handlers =
        {
            [ EVENT.MODIFIER_ADDED ] = function ( self, modifier, source )
                if modifier == self and self.engine then
                    if self.negotiator:GetModifierInstances(self.id) > 1 then
                        self.negotiator:RemoveModifier(self)
                        return
                    end
                    -- local has_card = false
                    -- for k,v in pairs(self.engine:GetHandDeck().cards) do
                    --     if v.id == "assassin_fight_describe_information" then
                    --         has_card = true
                    --     end
                    -- end
                    -- if not has_card then
                    --     self.engine:InsertCard(Negotiation.Card( "assassin_fight_describe_information", self.engine:GetPlayer() ))
                    -- end
                end
            end,
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                self.negotiator:AddModifier(self, 1, self)
            end,
            [ EVENT.MODIFIER_CHANGED ] = function( self, modifier, delta, clone )
                if modifier == self and modifier.stacks >= self.calls_required then
                    if self.negotiator:GetModifierStacks("HELP_UNDERWAY") <= 0 then
                        local stacks = 12
                        if self.engine and self.engine.help_turns then 
                            stacks = self.engine.help_turns 
                        end
                        self.negotiator:AddModifier("HELP_UNDERWAY", stacks)
                    end
                    
                    self.negotiator:RemoveModifier(self)
                    self.anti_negotiator:AddModifier("IMPATIENCE", 1)
                    -- self:CleanUpCard("assassin_fight_describe_information")
                end
            end,
        },
    },
    HELP_UNDERWAY = 
    {
        name = "Help Underway!",
        desc = "Distract <b>{1}</> for {2} more turns until the help arrives!\n\n" ..
            "If you lose the negotiation while help is underway, you can still keep {1} occupied " ..
            "through battle, and survive the assassination!",
        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.anti_negotiator and self.anti_negotiator:GetName() or "the opponent",  self.stacks)
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/help_underway.png",

        max_stacks = 20,
        
        modifier_type = MODIFIER_TYPE.PERMANENT,

        -- turns_left = rawget(_G, "SURVIVAL_TURNS") or 12,

        event_handlers = {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                
                if self.stacks <= 1 then
                    minigame:Win()
                else
                    self.negotiator:RemoveModifier(self, 1)
                    self:NotifyChanged()
                end
            end,
        }
    },
    DISTRACTION_ENTERTAINMENT = 
    {
        name = "Distraction: Entertainment",
        desc = "{MYRIAD_MODIFIER {2}}.\n\nWhen destroyed, {1} loses 1 {IMPATIENCE} if able.",
        icon = "negotiation/modifiers/card_draw.tex",
        
        modifier_type = MODIFIER_TYPE.BOUNTY,
        init_max_resolve = 10,

        bonus_per_generation = 2,
        bonus_scale = {2, 2, 3, 4},

        generation = 0,

        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.negotiator and self.negotiator:GetName() or "the opponent",
                CalculateBonusScale(self))
        end,
        OnInit = MyriadInit,
        OnBounty = function(self)
            if self.negotiator:GetModifierStacks("IMPATIENCE") > 0 then
                self.negotiator:RemoveModifier("IMPATIENCE", 1)
            end
            CreateNewSelfMod(self)
        end,
    },
    DISTRACTION_GUILTY_CONSCIENCE = 
    {
        name = "Distraction: Guilty Conscience",
        desc = "{MYRIAD_MODIFIER {2}}.\n\nWhen destroyed, remove a random intent and {1} gains 2 {VULNERABILITY}.",
        icon = "negotiation/modifiers/scruple.tex",

        modifier_type = MODIFIER_TYPE.BOUNTY,
        init_max_resolve = 10,

        bonus_per_generation = 2,
        bonus_scale = {2, 2, 3, 4},

        generation = 0,

        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.negotiator and self.negotiator:GetName() or "the opponent",
                CalculateBonusScale(self))
        end,
        OnInit = MyriadInit,
        OnBounty = function(self)
            local intents = {}
            for i, data in ipairs(self.negotiator:GetIntents()) do
                -- if data.id ~= "impatience" then
                table.insert(intents, data)
                -- end
            end
            
            if #intents > 0 then
                self.negotiator:DismissIntent(intents[math.random(#intents)])
            end
            self.negotiator:AddModifier("VULNERABILITY", 2)

            CreateNewSelfMod(self)
        end,
    },
    DISTRACTION_CONFUSION = 
    {
        name = "Distraction: Confusion",
        desc = "{MYRIAD_MODIFIER {2}}.\n\nWhen destroyed, {1} gain 2 {FLUSTERED}.",
        icon = "negotiation/modifiers/doubt.tex",
        
        modifier_type = MODIFIER_TYPE.BOUNTY,
        init_max_resolve = 10,

        bonus_per_generation = 2,
        bonus_scale = {2, 2, 3, 4},

        generation = 0,

        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.negotiator and self.negotiator:GetName() or "the opponent",
                CalculateBonusScale(self))
        end,
        OnInit = MyriadInit,
        OnBounty = function(self)

            self.negotiator:AddModifier("FLUSTERED", 2)

            CreateNewSelfMod(self)
        end,
    },

    LOADED_QUESTION = 
    {
        name = "Loaded Question",
        desc = "When destroyed, the player loses support equal to {1}.\n\n"..
        "When {address_question|addressed}, the player loses {2} support.",
        loc_strings = {
            NORMAL = "{1}x the splash damage, rounded up",
            HALF = "half the splash damage, rounded up",
            WHOLE = "the splash damage",
        },

        desc_fn = function(self, fmt_str)
            local str_id = self.multiplier_strings[self.multiplier] or "NORMAL"
            local str = loc.format((self.def or self):GetLocalizedString(str_id), self.multiplier)
            return loc.format( fmt_str, str, self.address_cost)
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/loaded_question.png",

        min_persuasion = 2,
        max_persuasion = 2,

        address_cost = 3,
        address_cost_scale = {2, 3, 4, 5},

        multiplier_strings = {
            [0.5] = "HALF",
            -- [0.75] = "THREE_QUARTER",
            [1] = "WHOLE",
        },
        multiplier = 0.5,
        multiplier_scale = {0.3, 0.5, 0.75, 1},

        target_enemy = TARGET_ANY_RESOLVE,

        max_stacks = 1,

        modifier_type = MODIFIER_TYPE.ARGUMENT,

        OnInit = function( self )
            self:SetResolve( 5, MODIFIER_SCALING.MED )
            if CheckBits(self.engine:GetFlags(), NEGOTIATION_FLAGS.WORDSMITH) then
                self.address_cost = self.address_cost_scale[
                    math.min( GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1,
                    #self.address_cost_scale)] 
                self.multiplier = self.multiplier_scale[
                    math.min( GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1,
                    #self.multiplier_scale) ]
            end
        end,

        OnBeginTurn = function( self, minigame )
            self:ApplyPersuasion()
        end,

        OnBounty = function(self)
            local mod = self.negotiator:CreateModifier("LOADED_QUESTION_DEATH_TRIGGER")
            mod.tracked_mod = self
            mod.multiplier = self.multiplier
        end,

        AddressQuestion = function(self)
            DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", -self.address_cost)
        end,
    },
    -- Kinda have to do it this way, since removed modifier no longer listens to events that happened because of the removal of self.
    LOADED_QUESTION_DEATH_TRIGGER = 
    {
        -- name = "Loaded Question(Death Trigger)",
        hidden = true,
        event_handlers = 
        {
            [ EVENT.SPLASH_RESOLVE ] = function( self, modifier, overflow, params )
                if self.tracked_mod and self.tracked_mod == modifier then
                    print("overflow damage:" .. overflow .. ", deal resolve damage")
                    local support_dmg = math.floor((self.multiplier or 1) * overflow)
                    DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", support_dmg)
                end
                print("triggered lul")
                self.negotiator:RemoveModifier(self)
            end
        },
    },
    GENERIC_QUESTION =
    {
        name = "Generic Question",
        desc = "Can be {address_question|addressed}, but does nothing special.",
        icon = "DEMOCRATICRACE:assets/modifiers/generic_question.png",

        min_persuasion = 2,
        max_persuasion = 2,

        damage_scale = {1, 2, 2, 3},

        target_enemy = TARGET_ANY_RESOLVE,

        max_stacks = 1,

        modifier_type = MODIFIER_TYPE.ARGUMENT,

        OnInit = function(self)
            self:SetResolve( 5, MODIFIER_SCALING.MED )
            if CheckBits(self.engine:GetFlags(), NEGOTIATION_FLAGS.WORDSMITH) then
                local dmg = self.damage_scale[
                    math.min( GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1,
                    #self.damage_scale)]
                self.min_persuasion = dmg
                self.max_persuasion = dmg 
            end
        end,

        OnBeginTurn = function( self, minigame )
            self:ApplyPersuasion()
        end,
        AddressQuestion = function(self)
            -- does literally nothing. but this is here to let the game know this is a valid question.
        end,
    },
    PLEASANT_QUESTION = 
    {
        name = "Pleasant Question",
        desc = "When destroyed or {address_question|addressed}, the player gains {1} resolve.",

        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.resolve_gain)
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/pleasant_question.png",

        min_persuasion = 2,
        max_persuasion = 2,

        resolve_gain = 2,
        resolve_scale = {5, 4, 3, 2},

        target_enemy = TARGET_ANY_RESOLVE,

        max_stacks = 1,

        modifier_type = MODIFIER_TYPE.ARGUMENT,

        OnInit = function( self )
            self:SetResolve( 5, MODIFIER_SCALING.MED )
            if CheckBits(self.engine:GetFlags(), NEGOTIATION_FLAGS.WORDSMITH) then
                self.resolve_gain = self.resolve_scale[
                    math.min( GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1,
                    #self.resolve_scale) ]
            end
        end,

        OnBeginTurn = function( self, minigame )
            self:ApplyPersuasion()
        end,

        OnBounty = function(self)
            self.anti_negotiator:RestoreResolve(self.resolve_gain, self)
        end,

        AddressQuestion = function(self)
            self.anti_negotiator:RestoreResolve(self.resolve_gain, self)
        end,
    },
    CONTEMPORARY_QUESTION = 
    {
        name = "Contemporary Question",
        desc = "The interviewer asks about your opinion on <b>{1}</>.\n\n"..
            "When {address_question|addressed}, the player must state their opinion on this matter.",
        icon = "DEMOCRATICRACE:assets/modifiers/contemporary_question.png",

        issue_data = nil,

        loc_strings = {
            ISSUE_DEFAULT = "a contemporary issue",
            CHOOSE_AN_ANSWER = "Choose An Answer",
        },
        
        max_stacks = 1,

        desc_fn = function(self, fmt_str)
            return loc.format( fmt_str, self.issue_data and self.issue_data:GetLocalizedName() or self.def:GetLocalizedString("ISSUE_DEFAULT"))
        end,
        OnInit = function( self )
            self:SetResolve( 6 + 2 * (GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1), MODIFIER_SCALING.MED )
        end,
        min_persuasion = 3,
        max_persuasion = 3,

        target_enemy = TARGET_ANY_RESOLVE,

        modifier_type = MODIFIER_TYPE.ARGUMENT,
        
        SetIssue = function(self, issue_data)
            self.issue_data = issue_data
        end,
        AddressQuestion = function(self)
            if self.issue_data ~= nil then
                local cards = {}
                local issue = self.issue_data
                for id = -2, 2 do
                    local data = issue.stances[id]
                    if data then
                        local card = Negotiation.Card( "question_answer", self.owner )
                        card.engine = self.engine
                        card:UpdateIssue(issue, id)
                        table.insert(cards, card)
                    end
                end
                local pick = self.engine:ChooseCardsFromTable( cards, 1, 1, nil, self.def:GetLocalizedString("CHOOSE_AN_ANSWER") )[1]
                if pick then
                    print(pick.name)
                    if pick.stance then
                        DemocracyUtil.TryMainQuestFn("UpdateStance", issue.id, pick.stance, false, true)
                        -- local stance = issue.stances[pick.stance]
                        -- if stance.faction_support then
                        --     DemocracyUtil.TryMainQuestFn("DeltaGroupFactionSupport", stance.faction_support)
                        -- end
                        -- if stance.wealth_support then
                        --     DemocracyUtil.TryMainQuestFn("DeltaGroupWealthSupport", stance.wealth_support)
                        -- end
                    end
                    self.engine:DealCard(pick, self.engine:GetTrashDeck())
                    print("should be expended")
                end

            end
        end,

        OnBeginTurn = function( self, minigame )
            self:ApplyPersuasion()
        end,
    },

    INTERVIEWER =
    {
        name = "Interviewer",
        desc = "At the end of {1}'s turn, apply 1 {COMPOSURE} to each of up to {2} random {2*argument|arguments} they control for every question arguments they have.\n\nAt the beginning of the player's turn, add an {address_question} card to the player's hand.",
        desc_fn = function(self, fmt_str )
            return loc.format(fmt_str, self:GetOwnerName(), self.composure_targets)
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/interviewer.png",

        -- icon = engine.asset.Texture("negotiation/modifiers/heckler.tex"),
        modifier_type = MODIFIER_TYPE.CORE,

        composure_targets = 2,

        target_scale = {1, 2, 3, 4},

        OnInit = function( self )
            self.composure_targets = self.target_scale[math.min(
                #self.target_scale, 
                GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 1)]
        end,
        
        OnEndTurn = function(self)
            local question_count = 0
            for i, data in self.negotiator:Modifiers() do
                if data.AddressQuestion then
                    question_count = question_count + 1
                end
            end
            -- local targets = {}
            local candidates = self.engine:CollectAlliedTargets(self.negotiator)
            -- for i, modifier in self.negotiator:ModifierSlots() do
            --     if modifier:GetResolve() ~= nil then
            --         table.insert( targets, {modifier=modifier, count=0} )
            --     end
            -- end
            local targets = {}
            for i = 1, self.composure_targets do
                if #candidates > 0 then
                    local chosen = math.random(#candidates)
                    table.insert(targets, candidates[chosen])
                    table.remove(candidates, chosen)
                end
            end
            for i, target in ipairs(targets) do
                target:DeltaComposure( question_count, self)
            end
        end,
        event_handlers = {
            [ EVENT.BEGIN_PLAYER_TURN ] = function( self, minigame )
                local card = Negotiation.Card( "address_question", minigame:GetPlayer() )
                card.show_dealt = false
                minigame:DealCards( {card}, minigame:GetHandDeck() )
            end,
            [ EVENT.MODIFIER_REMOVED ] = function( self, modifier )
                if modifier.AddressQuestion then
                    local behaviour = self.negotiator.behaviour
                    if not behaviour.params then behaviour.params = {} end
                    behaviour.params.questions_answered = (behaviour.params.questions_answered or 0) + 1
                end
            end,
        },
        InitModifiers = function(self)
            -- for i = 1, 2 + math.floor(self.engine:GetDifficulty() / 2) do
            --     self:TryCreateNewTarget()
            -- end
        end,
    },
    SECURED_INVESTEMENTS = 
    {
        name = "Secured Investments",
        icon = "negotiation/modifiers/frisk.tex",
        desc = "Gain {1} shills if the negotiation is successful.",
        alt_desc = "Gain shills equal to the number of stacks on this argument if the negotiation is successful.",
        desc_fn = function(self, fmt_str)
            if self.stacks then
                return loc.format(fmt_str, self.stacks)
            else
                return loc.format((self.def or self):GetLocalizedString("ALT_DESC"))
            end
        end,

        max_stacks = 999,
        
        modifier_type = MODIFIER_TYPE.PERMANENT,
    },
    INVESTMENT_OPPORTUNITY  = 
    {
        name = "Investment Opportunity",
        icon = "negotiation/modifiers/frisk.tex",
        desc = "{MYRIAD_MODIFIER {2}}\n\nWhen destroyed, gain {1} {SECURED_INVESTEMENTS}.",
        alt_desc = "{MYRIAD_MODIFIER {1}}\n\nWhen destroyed, gain {SECURED_INVESTEMENTS} equal to the number of stacks on this bounty.",

        desc_fn = function(self, fmt_str)
            if self.stacks then
                return loc.format(fmt_str, self.stacks or 1, self.bonus_per_generation)
            else
                return loc.format((self.def or self):GetLocalizedString("ALT_DESC"), self.bonus_per_generation)
            end
        end,

        -- max_resolve = 5,
        -- max_stacks = 1,
        bonus_per_generation = 2,

        modifier_type = MODIFIER_TYPE.BOUNTY,

        OnInit = function(self)
            if not self.init_max_resolve then
                self.init_max_resolve = math.ceil(self.stacks / 2.5)
            else
                self.init_max_resolve = self.init_max_resolve + self.bonus_per_generation
            end
            self:SetResolve(self.init_max_resolve, MODIFIER_SCALING.LOW)
        end,

        OnBounty = function(self, source)
            -- self.negotiator:CreateModifier("CAUTIOUS_SPENDER")
            self.anti_negotiator:AddModifier("SECURED_INVESTEMENTS", self.stacks)
            CreateNewSelfMod(self)
        end,
    },
    ETIQUETTE = 
    {
        name = "Etiquette",
        icon = "negotiation/modifiers/compromise.tex",
        desc = "Whenever you play a Hostility card discard a random card.",
    
        max_resolve = 5,
        max_stacks = 1,
        modifier_type = MODIFIER_TYPE.ARGUMENT,

        OnInit = function(self)
            self:SetResolve(self.max_resolve, MODIFIER_SCALING.MED)
        end,

        event_handlers =
        {
            [ EVENT.POST_RESOLVE ] = function( self, minigame, card )
                if card:GetNegotiator() == self.engine:GetPlayerNegotiator() then
                    if minigame:GetTurns() > 0 and card:IsFlagged( CARD_FLAGS.HOSTILE ) then
                        local card = self.engine:GetHandDeck():PeekRandom()
                        self.engine:DiscardCard( card )
                    end
                end
            end
        },
    },
    CAUTIOUS_SPENDER  = 
    {
        name = "Cautious Spender",
        icon = "negotiation/modifiers/obscurity.tex",
        desc = "At the begging of each turn, add {1} resolve to all {{2}} bounty.",

        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.delta_resolve, self.apply_target)
        end,

        max_resolve = 3,
        max_stacks = 1,

        delta_resolve = 2,
        apply_target = "INVESTMENT_OPPORTUNITY",

        modifier_type = MODIFIER_TYPE.ARGUMENT,

        OnInit = function(self)
            self:SetResolve(self.max_resolve, MODIFIER_SCALING.MED)
        end,

        event_handlers =
        {
            [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    for i, modifier in self.negotiator:ModifierSlots() do
                        if modifier.id == self.apply_target then
                            modifier:ModifyResolve( self.delta_resolve, self )
                            self:NotifyTriggered() 
                        end
                    end
                end
            end
        }
    },

    POSTER_SIMULATION_ENVIRONMENT = {
        name = "Simulation Environment",
        desc = "You are writing a propaganda poster in a simulation environment. This will record cards that you play onto your poster.\n\nYou can end the negotiation at any time if you concede, and you won't suffer any penalties.",
        alt_desc = "(Recorded Cards: {1#comma_listing})",

        desc_fn = function(self, fmt_str)
            if self.cards_played and #self.cards_played > 0 then
                local txt = {}
                for i, card in ipairs(self.cards_played) do
                    table.insert(txt, loc.format("{1#card}", card))
                end
                return fmt_str .. "\n\n" .. loc.format((self.def or self):GetLocalizedString("ALT_DESC"), txt)
            end
            return fmt_str
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/simulation_environment.png",


        modifier_type = MODIFIER_TYPE.CORE,
        max_stacks = 1,
        OnInit = function(self)
            if not self.cards_played then
                self.cards_played = {}
            end
        end,
        CanBeRecorded = function(self, card)
            -- we don't want unplayable cards to be recorded. and we also don't want opponent cards to be recorded.
            return self.engine:GetPlayerNegotiator() == card.negotiator and 
                not CheckBits( card.flags, CARD_FLAGS.UNPLAYABLE ) and
                not CheckAnyBits( card.flags, CARD_FLAGS.BYSTANDER ) and card.played_from_hand
                and not CheckAnyBits( card.flags, CARD_FLAGS.FLOURISH )
        end,

        CheckAllowRecord = function(self, source)
            if source and source == self.resolve_card then
                self.is_allowed = true
            end
        end,

        event_handlers = {
            [ EVENT.START_RESOLVE ] = function(self, minigame, card)
                if self:CanBeRecorded(card) and not self.resolve_card then
                    self.is_allowed = false
                    -- we only want the card the player directly plays from hand to be recorded.
                    -- "at sorcery speed", so to speak.
                    self.resolve_card = card
                end
            end,
            [ EVENT.END_RESOLVE ] = function(self, minigame, card)
                if self.resolve_card == card then
                    self.resolve_card = nil
                    if self.is_allowed then
                        table.insert(self.cards_played, card.id)
                    end
                end
            end,
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                self:CheckAllowRecord(source)
            end,
            [ EVENT.DELTA_COMPOSURE ] =  function( self, modifier, new_value, old_value, source, start_of_turn )
                self:CheckAllowRecord(source)
            end,
            [ EVENT.MODIFIER_ADDED ] = function( self, modifier, source )
                self:CheckAllowRecord(source)
            end,
            [ EVENT.MODIFIER_CHANGED ] = function( self, modifier, delta, clone, source )
                self:CheckAllowRecord(source)
            end,
            [ EVENT.MODIFIER_REMOVED ] = function ( self, modifier, source )
                self:CheckAllowRecord(source)
            end,
            [ EVENT.INTENT_REMOVED ] = function( self, card )
                self:CheckAllowRecord(card)
            end,
        },
    },
    SIMULATION_ARGUMENT = {
        name = "Simulation Argument",
        desc = "It literally does nothing. It's just there.",
        icon = "negotiation/modifiers/bidder.tex",
        modifier_type = MODIFIER_TYPE.ARGUMENT,
        max_resolve = 30,
    },
    TIME_CONSTRAINT = {
        name = "Time Is Money",
        desc = "Every 2 turns in this negotiation, you lose a free time action for the current quest.\n\n<#PENALTY>The negotiation will end if you ran out of actions for the quest!</>\n\n({1} actions left on the quest)",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.stacks)
        end,
        icon = "DEMOCRATICRACE:assets/modifiers/time_constraint.png",

        modifier_type = MODIFIER_TYPE.PERMANENT,
        -- max_stacks = 1,
        event_handlers = {
            [ EVENT.END_PLAYER_TURN ] = function ( self, minigame )
                if minigame:GetTurns() % 2 == 0 then
                    self.negotiator:RemoveModifier(self, 1)
                end
                if self.stacks <= 0 then
                    minigame:Lose()
                end
            end,
        },
    },
    ALTERNATIVE_CORE_ARGUMENT = {
        hidden = true,
        event_handlers = {
            [ EVENT.MODIFIER_REMOVED ] = function ( self, modifier )
                if modifier and modifier == self.tracked_modifier then
                    self.engine:Lose()
                end
            end,
        }
    },
    NO_PLAY_FROM_HAND = {
        loc_strings = {
            CANT_PLAY = "Can't play cards from hand",
        },
        hidden = true,
        CanPlayCardModifier = function( self, source, engine, target )
            
            if self.engine and self.engine:GetHandDeck():HasCard(source) then
                return false, (self.def or self):GetLocalizedString("CANT_PLAY")
            end

            return true
        end,
    },
	NARCISSISM = {
	    name = "Narcissism",
        desc = "At the start of {1}'s turn, create {2:a|{2} separate }{PRIDE} {2*argument|arguments}.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:GetOwnerName(), self:GetPrideCount(self.engine and self.engine:GetDifficulty() or 1))
        end,

        icon = "negotiation/modifiers/bidder.tex",
        modifier_type = MODIFIER_TYPE.CORE,
        max_stacks = 1,
        
        num_created = {1,1,2,2,2},
        GetPrideCount = function(self, difficulty)
            return self.num_created[math.min(difficulty, #self.num_created)]
        end,
        event_handlers =
        {
            [ EVENT.END_TURN ] = function ( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    for i = 1, self:GetPrideCount(self.engine and self.engine:GetDifficulty() or 1) do
                        self.negotiator:CreateModifier( "PRIDE", 1, self )
                    end
                end
			end,
		},
	},
	PRIDE = {
        name = "Pride",
        -- Having it heal while having 6 resolve is a bit too much, I think.
        desc = "At the start of {1}'s turn, apply {2} {COMPOSURE} to {1}'s core argument.",
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:GetOwnerName(), self.composure_gain)
        end,
		modifier_type = MODIFIER_TYPE.ARGUMENT,
		max_stacks = 1,
        max_resolve = 2,
        OnInit = function(self)
            self:SetResolve(self.max_resolve, MODIFIER_SCALING.LOW)
        end,
        composure_gain = 2,
		OnBeginTurn = function( self, minigame )
            self.negotiator:FindCoreArgument():DeltaComposure( self.composure_gain, self )
        end,
	},
	FRAGILE_EGO = {
		name = "Fragile Ego",
		desc = "Remove all {PRIDE}s and incept that much {VULNERABILITY}.",
		modifier_type = MODIFIER_TYPE.BOUNTY,
		max_stacks = 1,
        max_resolve = 4,
        OnInit = function(self)
            self:SetResolve(self.max_resolve, MODIFIER_SCALING.MED)
        end,
		OnBounty = function( self )
            local stacks = self.negotiator:GetModifierStacks("PRIDE")
            self.negotiator:RemoveModifier("PRIDE", stacks, self)
            self.negotiator:AddModifier("VULNERABILITY", stacks, self)
		end,
    },
    PLANTED_EVIDENCE_MODDED = 
    {
        name = "Planted Evidence",
        desc = "When this argument is destroyed, deal {1} damage to a random core argument on {2}'s side.",
        desc_fn = function( self, fmt_str )
            return loc.format( fmt_str, self.stacks or 2, self:GetOwnerName() )
        end,

        max_resolve = 1,

        modifier_type = MODIFIER_TYPE.BOUNTY,

        sound = "event:/sfx/battle/cards/neg/create_argument/strawman",
        icon = "negotiation/modifiers/planted_evidence.tex",

        OnBounty = function( self )
            local targets = {}
            for i, modifier in self.negotiator:ModifierSlots() do
                if modifier.modifier_type == MODIFIER_TYPE.CORE and not 
                    (modifier:GetShieldStatus() 
                    or modifier.max_resolve == nil) then
                    table.insert(targets, modifier)
                end
            end
            local target = table.arraypick(targets)
            self.engine:ApplyPersuasion( self, target, self.stacks, self.stacks )
        end,
    },
    APPROPRIATED_MODDED =
    {
        name = "Appropriated",
        desc = "When this argument is destroyed, all cards are returned to {2}'s hand. {2} gains 2 {VULNERABILITY}.",
        alt_desc = "When this argument is destroyed, all cards are returned to {2.fullname}'s card pool. The opponent gains 2 {VULNERABILITY}.",
        desc_fn = function( self, fmt_str, minigame, widget )
            if widget and widget.PostCard then
                for i, card in ipairs( self.stolen_cards) do
                    widget:PostCard( card.id, card, minigame )
                end
            end
            if self.stolen_from and self.stolen_from.available_cards then
                return loc.format((self.def or self):GetLocalizedString("ALT_DESC"), self:GetOwnerName(), 
                    self.stolen_from.candidate_agent and self.stolen_from.candidate_agent:LocTable())
            else
                return loc.format( fmt_str, self:GetOwnerName(), self:GetOpponentName() )
            end
        end,

        max_resolve = 1,
        max_stacks = 1,

        modifier_type = MODIFIER_TYPE.BOUNTY,
        removed_sound = "event:/sfx/battle/cards/neg/appropriator_cardreleased",
        icon = "negotiation/modifiers/appropriated.tex",
        --sound = "event:/sfx/battle/cards/neg/create_argument/strawman",

        OnInit = function( self )
            self.stolen_cards = {}
            self:SetResolve( 1, MODIFIER_SCALING.LOW )
        end,

        GetStolenCount = function( self )
            return #self.stolen_cards
        end,

        AppropriateCard = function( self, card, owner )
            table.insert( self.stolen_cards, card )
            if owner and owner.available_cards then
                table.arrayremove(owner.available_cards, card)
            end
            card:RemoveCard()
            self.stolen_from = owner

            self:NotifyChanged()
           
            self.engine:BroadcastEvent( EVENT.CARD_STOLEN, card, self )
        end,

        OnBounty = function( self )
            for i, card in ipairs( self.stolen_cards ) do
                
                if self.stolen_from and self.stolen_from.available_cards then
                    print("Return to the pool of stuff")
                    table.insert(self.stolen_from.available_cards, card)
                else
                    self.engine:BroadcastEvent( EVENT.CUSTOM, function( panel )
                        local slot_widget = panel:FindSlotWidget( self )
                        if slot_widget then
                            local w = panel.cards:CreateCardWidget( card )
                            local x, y = w.parent:TransformFromWidget( slot_widget, 0, 0 )
                            w:SetPos( x, y )
                        end
                    end )
                    card.show_dealt = false
                    self.engine:InsertCard( card )
                end
            end

            self.anti_negotiator:InceptModifier("VULNERABILITY", 2)
        end,
    },
    ALL_BUSINESS_MODDED =
    {
        name = "All Business",
        desc = "At the start of the turn, a random allied argument gains {COMPOSURE {1}} for each Hostility card in all opponents' intent.",
        alt_desc = "A random allied argument gains {COMPOSURE {1}} for each Hostility card the player draw.",
        desc_fn = function( self, fmt_str )
            if self.negotiator and not self.negotiator:IsPlayer() then
                return loc.format( fmt_str .. "\n" .. (self.def or self):GetLocalizedString("ALT_DESC"), self.bonus )
            else
                return loc.format( fmt_str, self.bonus )
            end
        end,

        max_resolve = 1,
        max_stacks = 1,
        bonus = 1,

        sound = "event:/sfx/battle/cards/neg/create_argument/all_business",
        icon = "negotiation/modifiers/all_business.tex",

        OnInit = function( self )
            if self.engine then
                local difficulty = self.engine:GetDifficulty()
                self:SetResolve( 1, MODIFIER_SCALING.MED )
                self.bonus = difficulty
            end
        end,

        event_handlers =
        {
            [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                if negotiator == self.negotiator then
                    local did_a_thing = false
                    for i, modifier in self.anti_negotiator:ModifierSlots() do
                        if modifier.prepared_cards then
                            for j, card in ipairs(modifier.prepared_cards) do
                                if card:IsFlagged( CARD_FLAGS.HOSTILE ) then
                                    -- self.negotiator:DeltaComposure( self.bonus, self )
                                    local targets = self.engine:CollectAlliedTargets(self.negotiator)
                                    if #targets > 0 then
                                        local target = targets[math.random(#targets)]
                                        target:DeltaComposure(self.bonus, self)
                                        -- self:AddXP(1)
                                        did_a_thing = true
                                    end
                                    
                                end
                            end
                        end
                    end
                    if did_a_thing then
                        self:NotifyTriggered()
                    end
                end
            end,
            [ EVENT.DRAW_CARD ] = function( self, engine, card, start_of_turn )
                if card:IsFlagged( CARD_FLAGS.HOSTILE ) and self.negotiator and not self.negotiator:IsPlayer() then
                    -- self.negotiator:DeltaComposure( self.bonus, self )
                    local targets = self.engine:CollectAlliedTargets(self.negotiator)
                    if #targets > 0 then
                        local target = targets[math.random(#targets)]
                        target:DeltaComposure(self.bonus, self)
                        -- self:AddXP(1)
                    end
                    self:NotifyTriggered()
                end
            end,
        },
    },
    DEBATE_SCRUM_TRACKER =
    {
        name = "Debate Host",
        desc = "Defeat ALL opponent negotiators to win this debate!\n\n" ..
            "You cannot play any more cards if your core argument is destroyed, and you lose if your core argument and all your allies' core argument are destroyed.\n\n" ..
            "Opponents arguments comes in to play with +{1} resolve.\n\n" ..
            "Perform various feats to score points and win the crowd. <#PENALTY>Your allies will also do the same, so score more than your allies to stand out!</>",
        loc_strings = {
            SCORE_DAMAGE = "Damage Dealt",
            SCORE_FULL_BLOCK = "Damage Deflected",
            SCORE_ARGUMENT_DESTROYED = "Argument Refuted",
            SCORE_OPPONENT_DESTROYED = "Opponent Refuted",
            SCORE_ARGUMENT_CREATED = "Argument Created",
            SCORE_ARGUMENT_INCEPTED = "Argument Incepted",
            SCORE_DELTA = "+{1} Pts",
        },
        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self:GetBonusResolve())
        end,
        
        modifier_type = MODIFIER_TYPE.CORE,
        max_stacks = 1,

        bonus_resolve = {2, 3, 4, 5},
        GetBonusResolve = function(self)
            local boss_scale = GetAdvancementModifier( ADVANCEMENT_OPTION.NPC_BOSS_DIFFICULTY ) or 2
            if self.engine and CheckBits(self.engine:GetFlags(), NEGOTIATION_FLAGS.WORDSMITH) then
                return self.bonus_resolve[math.min(#self.bonus_resolve, boss_scale)]
            end
            return self.bonus_resolve[2]
        end,

        OnInit = function(self)
            self.scores = {}
            self.player_score = 0
            
            self.score_widgets = {}
            self.player_score_widget = {}

            -- self:DeltaScore(200, nil, "SCORE_DAMAGE")
            -- self:DeltaScore(100, nil, "SCORE_DAMAGE")
        end,
        
        GetScoreText = function(self, delta, reason, multiplier)
            local res
            if self.loc_strings[reason] then
                res = (self.def or self):GetLocalizedString(reason)
            else
                res = ""
            end
            if res ~= "" then
                res = res .. " "
            end
            if multiplier and multiplier > 1 then
                res = res .. "x" .. multiplier
            end
            if res ~= "" then
                res = res .. " "
            end
            
            return loc.format( res ..
                (self.def or self):GetLocalizedString("SCORE_DELTA"), delta)
        end,
        DeltaScore = function(self, delta, source, reason)
            local function PopupText(panel, source_widget, deltay, text_color, widget_list)
                if delta == 0 then
                    return
                end
                print(loc.format("{1} gains {2} pts because of {3}", source, delta, reason))
                for i, data in ipairs(widget_list) do
                    if data and data.reason and data.reason == reason then
                        data.score = (data.score or 0) + delta
                        data.multiplier = (data.multiplier or 1) + 1
                        data.label:SetText(self:GetScoreText(data.score, reason, data.multiplier))
                        return
                    end
                end
                local label = panel:AddChild( Widget.Label( "title", 28, self:GetScoreText(delta, reason) ):SetBloom( 0.1 ))
                local insert_index = 1
                while widget_list[insert_index] ~= nil do
                    insert_index = insert_index + 1
                end
                widget_list[insert_index] = {score = delta, multiplier = 1, label = label, reason = reason}
                label:SetGlyphColour( text_color )
                    :SetOutlineColour( 0x000000FF )
                    :EnableOutline( 0.25 )
                
                local screenw, screenh = panel:GetFE():GetScreenDims()
                local sx, sy
                if source_widget then
                    sx, sy = panel:TransformFromWidget(source_widget, 0, 0)
                else
                    -- LOGWARN("Fail to find minigame objective for some reason")
                    sx, sy = screenw / 2, screenh / 2
                end
                label:AlphaTo(0, 0)
                label:SetPos( sx, sy + (insert_index - 1) * deltay)

                label:MoveTo( sx, sy + insert_index * deltay, 0.2, easing.outQuad )
                label:AlphaTo(1, 0.2)
                -- label:Delay(1)
                local t = 2
                local prev_tick = widget_list[insert_index].multiplier
                while (t > 0) do 
                    local dt = coroutine.yield()
                    t = t - dt
                    if widget_list[insert_index].multiplier ~= prev_tick then
                        prev_tick = widget_list[insert_index].multiplier
                        t = 2
                    end
                end

                widget_list[insert_index] = nil

                label:MoveTo( sx, sy + (insert_index + 1) * deltay, 0.2, easing.inQuad )
                label:AlphaTo(0, 0.2)
                label:Delay(0.2)
                label:Remove()
                
            end
            if type(source) == "number" then
                if self.scores[source] then
                    source = self.scores[source].modifier
                else
                    source = self.engine:FindModifierByUID(source)
                end
            end
            if type(source) == "table" then
                source = source.real_owner
                if source then
                    -- Give the AI an edge. This way we can get away with lower damage output while
                    -- making the score race still a challenge
                    delta = delta * 2
                    if not self.scores[source:GetUID()] then
                        self.scores[source:GetUID()] = {modifier = source, score = 0}
                    end
                    
                    if not self.score_widgets[source:GetUID()] then
                        self.score_widgets[source:GetUID()] = {}
                    end
                    self.engine:BroadcastEvent(EVENT.CUSTOM, function(panel)
                        -- panel:RefreshReason()
                        local source_widget = panel:FindSlotWidget( source )
                        if source_widget then
                            self.scores[source:GetUID()].score = self.scores[source:GetUID()].score + delta
                            source:NotifyChanged()
                            panel:StartCoroutine(PopupText, panel, source_widget, 32, UICOLOURS.WHITE, self.score_widgets[source:GetUID()])
                        end
                    end)
                    return
                end 
            end
            local is_source_incepted = source and (source.modifier_type == MODIFIER_TYPE.BOUNTY or source.modifier_type == MODIFIER_TYPE.INCEPTION)
            if source == nil or (source.negotiator:IsPlayer() and not is_source_incepted) or (source.anti_negotiator:IsPlayer() and is_source_incepted) then
                
                self.engine:BroadcastEvent(EVENT.CUSTOM, function(panel)
                    panel:RefreshReason()
                    local source_widget = self.engine:GetPlayerNegotiator():FindCoreArgument() and 
                        panel:FindSlotWidget( self.engine:GetPlayerNegotiator():FindCoreArgument() ) or nil--panel.main_overlay.minigame_objective
                    self.player_score = self.player_score + delta
                    panel:StartCoroutine(PopupText, panel, source_widget, 32, UICOLOURS.WHITE, self.player_score_widget)
                    panel.player_modifiers:UpdatePersuasionLabels()
                    panel.opponent_modifiers:UpdatePersuasionLabels()
                end)
            end
        end,
        CheckGameOver = function(self)
            for i, mod in self.negotiator:Modifiers() do
                if mod.modifier_type == MODIFIER_TYPE.CORE and mod ~= self then
                    return
                end
            end
            if not self.engine:CheckGameOver() then
                self.engine:Win()
            end
        end,
        event_priorities =
        {
            [ EVENT.ATTACK_RESOLVE ] = 999,
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_SETTOR, 
        },
        event_handlers =
        {
            [ EVENT.START_RESOLVE ] = function(self, minigame, card)
                card.damages_during_play = {}
            end,
            [ EVENT.END_RESOLVE ] = function(self, minigame, card)
                if card.damages_during_play then
                    -- print(loc.format("{1#listing}", card.damages_during_play))
                    local delta_score = 0
                    table.sort(card.damages_during_play, function(a,b) return a > b end)
                    for i, dmg in ipairs(card.damages_during_play) do
                        -- Gains full score for the first two hits.
                        -- Then, exponentially decrease score gained.
                        delta_score = delta_score + math.ceil(dmg / math.max(1, math.pow(2, i - 1)))
                    end
                    if delta_score > 0 then
                        self:DeltaScore(delta_score * 1, card, "SCORE_DAMAGE")
                    end
                end
                card.damages_during_play = nil
            end,
            [ EVENT.ATTACK_RESOLVE ] = function( self, source, target, damage, params, defended )
                if params and params.splashed_modifier then
                    return
                end
                if source.negotiator == target.negotiator then
                    return -- self harm, does nothing.
                end
                if damage > defended then
                    print(loc.format("{1} dealt {3} damage to {2}", source, target, damage - defended))
                    if source.damages_during_play then
                        table.insert(source.damages_during_play, damage - defended)
                        return
                    end
                    -- print(loc.format("{1} dealt damage(real_owner={2})", source, source and source.real_owner))
                    self:DeltaScore((damage - defended) * 1, source, "SCORE_DAMAGE")

                    -- if target == self.engine:GetPlayerNegotiator():FindCoreArgument() and not target.real_owner then
                    --     local cmp_delta = math.floor((damage - defended) / 2)
                    --     target.composure = target.composure + cmp_delta
                    -- end
                else
                    if target.composure_applier then
                        ----------------------------
                        -- Option 1: Anyone who applied composure share the score gained from deflection.
                        ----------------------------
                        local scorer = {}
                        for id, val in pairs(target.composure_applier) do
                            if val > 0 then
                                table.insert_unique(scorer, id)
                            end
                        end
                        local multiplier = math.max(0.5, 1 - 0.25 * (#scorer - 1))
                        for i, id in ipairs(scorer) do
                            if type(id) == "number" then
                                self:DeltaScore(math.ceil(damage * multiplier), id, "SCORE_FULL_BLOCK")
                            else
                                self:DeltaScore(math.ceil(damage * multiplier), nil, "SCORE_FULL_BLOCK")
                            end
                        end
                    end
                end
            end,
            [ EVENT.DELTA_COMPOSURE ] =  function( self, modifier, new_value, old_value, source, start_of_turn )
                local delta = new_value - old_value
                if delta > 0 then
                    if not modifier.composure_applier then
                        modifier.composure_applier = {}
                    end
                    if source and source.negotiator == modifier.negotiator then
                        if source.real_owner then
                            modifier.composure_applier[source.real_owner:GetUID()] = (modifier.composure_applier[source.real_owner:GetUID()] or 0) + delta
                            -- Simply register this modifier in case it gets destroyed later.
                            self:DeltaScore(0, modifier, "SCORE_FULL_BLOCK")
                        elseif source:IsPlayerOwner() then
                            modifier.composure_applier["PLAYER"] = (modifier.composure_applier["PLAYER"] or 0) + delta
                        end
                    end
                end
                if new_value <= 0 then
                    modifier.composure_applier = nil
                end
            end,
            [ EVENT.MODIFIER_ADDED ] = function ( self, modifier, source )
                if source and source.real_owner then
                    modifier.real_owner = source.real_owner
                end
                if modifier.negotiator == self.negotiator and modifier.modifier_type == MODIFIER_TYPE.ARGUMENT then
                    modifier:ModifyResolve(self:GetBonusResolve(), self)
                end
                if source and source.negotiator == modifier.negotiator and modifier.modifier_type == MODIFIER_TYPE.ARGUMENT then
                    self:DeltaScore(3, source, "SCORE_ARGUMENT_CREATED")
                end
                if source and source.negotiator == modifier.anti_negotiator and 
                    (modifier.modifier_type == MODIFIER_TYPE.BOUNTY or modifier.modifier_type == MODIFIER_TYPE.INCEPTION) then
                    
                    self:DeltaScore(3, source, "SCORE_ARGUMENT_INCEPTED")
                end
            end,
            [ EVENT.MODIFIER_REMOVED ] = function( self, modifier, source )
                if source and source.negotiator ~= modifier.negotiator then
                    if modifier.modifier_type == MODIFIER_TYPE.CORE then
                        self:DeltaScore(25, source, "SCORE_OPPONENT_DESTROYED")
                        self:CheckGameOver()
                        if modifier.negotiator == self.negotiator then
                            
                        else
                            for i, mod in self.anti_negotiator:Modifiers() do
                                if mod.modifier_type == MODIFIER_TYPE.CORE and not mod.candidate_agent then
                                    return
                                end
                            end
                            -- only other candidates are left. You can no longer do anything.
                            local minigame = self.engine
                            minigame.hand_deck:TransferCards( minigame.trash_deck )
                            minigame.draw_deck:TransferCards( minigame.trash_deck )
                            minigame.discard_deck:TransferCards( minigame.trash_deck )
                            -- self.resolve_deck:TransferCards( self.trash_deck )
                        end
                    else
                        self:DeltaScore(3, source, "SCORE_ARGUMENT_DESTROYED")
                    end
                end
            end,
            [ EVENT.SPLASH_RESOLVE ] = function( self, modifier, overflow, params )
                if modifier.real_owner and modifier.real_owner:IsApplied() and modifier.real_owner.negotiator == modifier.negotiator then
                    params.splashed_modifier = modifier.real_owner
                else
                    if not modifier:IsPlayerOwner() or not modifier.negotiator:FindCoreArgument().real_owner then
                        local splash_targets = {}
                        for i, mod in modifier.negotiator:Modifiers() do
                            if mod.modifier_type == MODIFIER_TYPE.CORE and mod:GetResolve() ~= nil and not mod:GetShieldStatus() then
                                table.insert(splash_targets, mod)
                            end
                        end
                        if #splash_targets > 0 then
                            params.splashed_modifier = table.arraypick(splash_targets)
                        end
                    end
                end
            end,
            [ EVENT.BEGIN_TURN ] = function( self, minigame, negotiator )
                self:CheckGameOver()
            end,
        },
    },
    CROWD_OPINION =
    {
        name = "Crowd Opinion",
        desc = "Bring the crowd to your side by playing {2#card}.\n\nWhenever {1} destroys an argument or bounty you have, reduce the stacks of this argument by 1 and remove a {2#card} from your deck.",
        loc_strings = {
            CURRENT_OPINION = "The crowd's current opinion is {1}.",
            NAME_1 = "<#PENALTY>Hostile</>",
            NAME_2 = "<#PENALTY>Skeptical</>",
            NAME_3 = "Divisive",
            NAME_4 = "<#BONUS>Sympathetic</>",
            NAME_5 = "<#BONUS>Supportive</>",

            BONUS_DMG = "{1} deals 1 bonus damage to {2}.",
        },
        icon = "DEMOCRATICRACE:assets/modifiers/crowd_opinion_1.png",
        icon_levels = {
            "DEMOCRATICRACE:assets/modifiers/crowd_opinion_1.png",
            "DEMOCRATICRACE:assets/modifiers/crowd_opinion_2.png",
            "DEMOCRATICRACE:assets/modifiers/crowd_opinion_3.png",
            "DEMOCRATICRACE:assets/modifiers/crowd_opinion_4.png",
            "DEMOCRATICRACE:assets/modifiers/crowd_opinion_5.png",
        },
        desc_fn = function(self, fmt_str)
            local desc_lst = {}
            if self.engine and self.stacks then
                table.insert(desc_lst, loc.format((self.def or self):GetLocalizedString("CURRENT_OPINION"), (self.def or self):GetLocalizedString("NAME_" .. self.stacks)))
                if self.stacks < 3 then
                    table.insert(desc_lst, loc.format((self.def or self):GetLocalizedString("BONUS_DMG"), self:GetOwnerName(), self:GetOpponentName()))
                elseif self.stacks > 3 then
                    table.insert(desc_lst, loc.format((self.def or self):GetLocalizedString("BONUS_DMG"), self:GetOpponentName(), self:GetOwnerName()))
                end
            end
            table.insert(desc_lst, loc.format(fmt_str, self:GetOwnerName(), "appeal_to_crowd_quest"))
            return table.concat(desc_lst, "\n")
        end,

        modifier_type = MODIFIER_TYPE.PERMANENT,
        max_stacks = 5,

        OnSetStacks = function(self, old_stacks)
            local new_stacks = self.stacks
            -- print(new_stacks)
            -- print("newicon: ", self.icon_levels[new_stacks])
            self.icon = self.icon_levels[new_stacks] and engine.asset.Texture(self.icon_levels[new_stacks]) or self.icon
            self.engine:BroadcastEvent( EVENT.UPDATE_MODIFIER_ICON, self)
        end,
        
        event_priorities = {
            [ EVENT.CALC_PERSUASION ] = EVENT_PRIORITY_ADDITIVE, 
        },
        event_handlers = {
            [ EVENT.CALC_PERSUASION ] = function( self, source, persuasion, minigame, target )
                if source and target then
                    if self.stacks < 3 then
                        if self.negotiator == source.negotiator and self.anti_negotiator == target.negotiator then
                            persuasion:AddPersuasion(1, 1, self)
                        end
                    elseif self.stacks > 3 then
                        if self.anti_negotiator == source.negotiator and self.negotiator == target.negotiator then
                            persuasion:AddPersuasion(1, 1, self)
                        end
                    end
                end
            end,
            [ EVENT.MODIFIER_REMOVED ] = function(self, modifier, source)
                if modifier.negotiator == self.anti_negotiator and (modifier.modifier_type == MODIFIER_TYPE.ARGUMENT or modifier.modifier_type == MODIFIER_TYPE.BOUNTY) then
                    if source and source.negotiator == self.negotiator then
                        if self.stacks > 1 then
                            self.negotiator:RemoveModifier(self, 1, self)
                        end
                        local all_cards = table.merge( self.engine:GetDrawDeck().cards, self.engine:GetDiscardDeck().cards, self.engine:GetHandDeck().cards )
                        for i, card in ipairs(all_cards) do
                            if card.id == "appeal_to_crowd_quest" then
                                self.engine:ExpendCard(card)
                                break
                            end
                        end
                    end
                end
            end,
        },
    },
    INSTIGATE_CROWD =
    {
        name = "Instigate Crowd",
        desc = "{MYRIAD_MODIFIER {1}}.\n\nWhen destroyed, add a {2#card} to your draw pile.",
        icon = "negotiation/modifiers/influence.tex",

        desc_fn = function(self, fmt_str)
            return loc.format(fmt_str, self.bonus_per_generation, "appeal_to_crowd_quest")
        end,

        modifier_type = MODIFIER_TYPE.BOUNTY,
        init_max_resolve = 2,

        bonus_per_generation = 2,
        -- bonus_scale = {2, 2, 3, 4},

        generation = 0,

        OnInit = function(self)
            self.bonus_per_generation = math.ceil(self.engine:GetDifficulty() / 2)
            if self.generation and self.generation > 0 then
                self.init_max_resolve = self.init_max_resolve + self.bonus_per_generation
            end
            self:SetResolve(self.init_max_resolve, MODIFIER_SCALING.MED)
        end,
        OnBounty = function(self)
            local card = Negotiation.Card("appeal_to_crowd_quest", self.engine:GetPlayer()) 
            self.engine:InceptCard( card, self )
            CreateNewSelfMod(self)
        end,
    },
}
for id, def in pairs( MODIFIERS ) do
    Content.AddNegotiationModifier( id, def )
end
Content.GetNegotiationModifier("FREE_ACTION").min_stacks = -99
local FEATURES = {
    MYRIAD_MODIFIER = 
    {
        name = "Myriad",
        desc = "When this bounty is destroyed, create a bounty that is a copy of this bounty with full resolve, except it has an extra starting resolve equal to the number indicated by {MYRIAD_MODIFIER}.",
        loc_strings = {
            NO_GAIN = "When this bounty is destroyed, create a bounty that is a copy of this bounty with full resolve.",
            STACKS = "When this bounty is destroyed, create a bounty that is a copy of this bounty with full resolve, except it has {1} extra starting resolve.",
        },
        desc_fn = function(self, fmt_str, stacks)
            if stacks then
                if stacks ~= 0 then
                    return loc.format(self:GetLocalizedString("STACKS"), stacks)
                else
                    return self:GetLocalizedString("NO_GAIN")
                end
            end
            return fmt_str
        end,
    },
}
for id, data in pairs(FEATURES) do
	local def = NegotiationFeatureDef(id, data)
	Content.AddNegotiationCardFeature(id, def)
end
