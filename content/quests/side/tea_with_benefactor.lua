-- don't declare variables that ties to the quest outside of quest defs unless they are constant
-- local main_negotiator
-- local main_negotiator_limiter = 0
local BENEFACTOR_DEFS = {
    WEALTHY_MERCHANT = "PROPOSITION",
    SPARK_BARON_TASKMASTER = "APPROPRIATOR",
    PRIEST = "ZEAL",
}
-- for balancing reasons
local SIGNATURE_ARGUMENT = {
    WEALTHY_MERCHANT = "TRIBUTE",
    PRIEST = "prayer_of_hesh", -- why this is lower case, i have no idea
}

-- local LOCATION_DEF =
-- {
--     id = "TEAHOUSE",
--     name = "Dallie's Teahouse",
--     desc = " [p] A small establishment with delicious tea and high concentration of influencieal individuals.",
--     -- icon = engine.asset.Texture("icons/quests/at_the_crossroad.tex"),
--     map_tags = {"residence"},
--     plax = "INT_RichHouse_1",
--     indoors = true,
--     show_agents= true,
-- }
-- if not Content.GetLocationContent(LOCATION_DEF.id) then
--     Content.AddLocationContent(LOCATION_DEF)
-- end

local score_fn = function(agent, quest)
    local score = DemocracyUtil.OppositionScore(agent)
    if agent:HasAspect( "bribed" ) then
        score = score + 90
    end
    return score + math.random() * 120
end

local BENEFACTOR_BEHAVIOR = {
    OnInit = function( self, difficulty )
        -- local modifier
        self.arguments = self:MakePicker()
            :AddArgument( "ETIQUETTE", 1 )
            :AddArgument( "CAUTIOUS_SPENDER", 1 )
        -- self.etiquette = self:
        -- self.cautious_spender = self:
        if SIGNATURE_ARGUMENT[self.agent:GetContentID()] then
            self.signature = self:AddArgument(SIGNATURE_ARGUMENT[self.agent:GetContentID()])
        end
        
        self:SetPattern( self.BasicCycle )
        
        self.negotiator:AddModifier(BENEFACTOR_DEFS[self.agent:GetContentID()])
        
    end,
    agents = {},

	-- Will probably get unique core argument (POSITION OF POWER) and possibly argument that spawns every x (4) turns
    BasicCycle = function( self, turns )
        -- This will trigger every turn, and we don't want that
        -- local etiquette = self:AddArgument( "ETIQUETTE" )

        -- Also, remove unnecessary checks
        if turns % 3 == 0 then
            self:ChooseGrowingNumbers(2, -1)
        else
            self:ChooseGrowingNumbers(1, 1)
        end

        if turns % 3 == 1 then
            self.arguments:ChooseCard()
        elseif turns % 3 == 2 then
            if self.signature and math.random(0, self.signature_played or 0) == 0 then
                self:ChooseCard(self.signature)
                self.signature_played = (self.signature_played or 0) + 1
            end
        end
        if turns % 2 == 0 then
            self:ChooseComposure( 1, self.difficulty, self.difficulty + 2 )
        end

	end,
}
local FOLLOWUP

local QDEF = QuestDef.Define
{
    title = "Tea with a benefactor",
    desc = "An influential citizen has taken interest in your campaign and invited you for a cup of tea. See if you can turn some of that support into cash.",

    qtype = QTYPE.SIDE,
    act_filter = DemocracyUtil.DemocracyActFilter,
    focus = QUEST_FOCUS.NEGOTIATION,
    tags = {"RALLY_JOB"},
    reward_mod = 0,
    extra_reward = false,
    precondition = function(quest)
        return TheGame:GetGameState():GetMainQuest():GetCastMember("primary_advisor") and true or false
    end,
    on_init = function(quest)
        -- quest.param.debated_people = 0
        -- quest.param.crowd = {}
        -- quest.param.convinced_people = {}
        -- quest.param.unconvinced_people = {}
    end,
    on_start = function(quest)
        quest:Activate("go_to_diner")
    end,
    -- icon = engine.asset.Texture("icons/quests/bounty_hunt.tex"),

    -- on_destroy = function( quest )
        
    -- end,
    on_complete = function( quest )
        DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", 4 )
    end,
    on_fail = function(quest)
        DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", -2 )
    end,
}
:AddLocationCast{
    cast_id = "diner",
    -- when = QWHEN.MANUAL,
    -- no_validation = true,
    condition = function(location, quest)
        local allowed_locations = {"PEARL_FANCY_EATS"}
        return table.arraycontains(allowed_locations, location:GetContentID())
    end,
}
:AddObjective{
    id = "go_to_diner",
    title = "Go to {diner#location}",
    desc = "Go to {diner#location} to meet the benefactor.",
    mark = { "benefactor" },
    state = QSTATUS.ACTIVE,
    
    on_activate = function( quest)
        -- local location = Location( LOCATION_DEF.id )
        -- assert(location)
        -- TheGame:GetGameState():AddLocation(location)
        -- quest:AssignCastMember("diner", location )
    end,
}
-- :AddObjective{
--     id = "secure_funding",
--     title = "Secure Funding",
--     desc = "Persuade the benefactor into financing your campaign.",
-- }
:AddCast{
    cast_id = "benefactor",
    -- when = QWHEN.MANUAL,
    -- no_validation = true,
    condition = function(agent, quest)
        return BENEFACTOR_DEFS[agent:GetContentID()] ~= nil -- might generalize it later
    end,
    -- don't use cast_fn by default if you want to use existing agents.
    -- cast_fn = function(quest, t)

    --     local options = {}
    --     table.insert(options, "WEALTHY_MERCHANT")
    --     table.insert(options, "SPARK_BARON_TASKMASTER")
    --     table.insert(options, "PRIEST")
    
    --     local def = options[math.random(#options)]
    --     table.insert( t, quest:CreateSkinnedAgent( def ) )
 
    --     if main_negotiator_limiter == 0 then
    --         main_negotiator = def
    --         main_negotiator_limiter = 1
    --     end

    -- end,
    score_fn = score_fn,
}
:AddCastFallback{
    cast_fn = function(quest, t)
        local options = copykeys(BENEFACTOR_DEFS)
        local def = table.arraypick(options)
        table.insert( t, quest:CreateSkinnedAgent(def) )
    end,
}
:AddOpinionEvents{
    convinced_benefactor =  
    {
        delta = OPINION_DELTAS.LIKE,
        txt = "Confident in your leadership abilities.",
    },
    disappointed_benefactor = {
        delta = OPINION_DELTAS.DIMINISH,
        txt = "Skeptical about your leadership abilities.",
    },
}
DemocracyUtil.AddPrimaryAdvisor(QDEF, true) -- make primary advisor mandatory because that's how you get that info

QDEF:AddConvo("go_to_diner")
    
    :Confront(function(cxt)
        if cxt.location == cxt.quest:GetCastMember("diner") and not cxt.quest.param.visited_diner then
            return "STATE_INTRO"
        end
    end)
    :State("STATE_INTRO")
        :Loc{
            DIALOG_INTRO = [[
                * You arrive at the diner looking for the benefactor.
                * One person watches you intensly and points to an empty chair.
            ]],
            
        }
        :Fn(function(cxt)

            cxt:Dialog("DIALOG_INTRO")
            cxt.quest.param.visited_diner = true
            
        end)
QDEF:AddConvo("go_to_diner", "benefactor")
    :Loc{
        OPT_TALK = "Start the meeting",
        DIALOG_TALK = [[
            player:
                [p] Alright, what do you want?
            agent:
                I am considering funding your campaign...
        ]],

        REASON_TALK = "Secure as much shills as you can!",
            
        DIALOG_BENEFACTOR_CONVINCED = [[
            agent:
                You look promising.
                I can provide {funds#money} for your campaign.
            player:
                Thanks.
            * [p] You have secured additional financial support.
        ]],
        DIALOG_BENEFACTOR_POOR = [[
            agent:
                [p] Unfortunately, I am not thoroughly convinced.
                I can only provide {funds#money} for you.
            player:
                I guess this is better than nothing.
            * You have secured a bit of financial support, though it could be a lot better.
        ]],
        DIALOG_BENEFACTOR_UNCONVINCED = [[
            * [p] You have successfuly snuffed out any interest that may have been there.
        ]],

        DIALOG_REGULAR_FUNDING = [[
            agent:
                [p] Since I like you, I will provide additional funding for you each morning.
                I'll give you half of what I gave you today every morning, as long as I am happy.
            player:
                Okay, thanks.
        ]],
    }
    :Hub(function(cxt)
        -- cxt.enc:SetPrimaryCast(cxt.quest:GetCastMember("benefactor"))
        cxt:Opt("OPT_TALK")
            :SetQuestMark(cxt.quest)
            :Dialog("DIALOG_TALK")
            :Fn(function(cxt)
                cxt:GetAgent().temp_negotiation_behaviour = BENEFACTOR_BEHAVIOR
            end)
            :Negotiation{
                flags = NEGOTIATION_FLAGS.NO_BYSTANDERS,
                reason_fn = function(minigame)
                    return cxt:GetLocString("REASON_TALK")
                end,

                on_start_negotiation = function(minigame)
                    -- just so you get at least something on win instead of nothing.
                    minigame.player_negotiator:CreateModifier("SECURED_INVESTEMENTS", 5)
                    minigame.opponent_negotiator:CreateModifier("INVESTMENT_OPPORTUNITY", 5)
                    minigame.opponent_negotiator:CreateModifier("INVESTMENT_OPPORTUNITY", 10)
                    minigame.opponent_negotiator:CreateModifier("INVESTMENT_OPPORTUNITY", 20)
                end,

                on_success = function(cxt, minigame)
                    cxt.quest.param.funds = minigame:GetPlayerNegotiator():GetModifierStacks( "SECURED_INVESTEMENTS" )
                    cxt.quest.param.poor_performance = cxt.quest.param.funds < 20 + 10 * cxt.quest:GetRank()
                    if cxt.quest.param.poor_performance then
                        cxt:Dialog("DIALOG_BENEFACTOR_POOR")
                    else
                        cxt:Dialog("DIALOG_BENEFACTOR_CONVINCED")
                    end
                    cxt.enc:GainMoney( cxt.quest.param.funds )
                    cxt:GetAgent():OpinionEvent(cxt.quest:GetQuestDef():GetOpinionEvent("convinced_benefactor"))
                    cxt.quest:Complete()
                    ConvoUtil.GiveQuestRewards(cxt)
                    if not cxt.quest.param.poor_performance and cxt:GetAgent():GetRelationship() > RELATIONSHIP.NEUTRAL then
                        cxt:Dialog("DIALOG_REGULAR_FUNDING")
                        cxt.quest:SpawnFollowQuest(FOLLOWUP.id)
                    end
                end,
                on_fail = function(cxt, minigame)
                    cxt:GetAgent():OpinionEvent(cxt.quest:GetQuestDef():GetOpinionEvent("disappointed_benefactor"))
                    cxt:Dialog("DIALOG_BENEFACTOR_UNCONVINCED")
                    cxt.quest:Fail()
                end,
            }
    end)
QDEF:AddConvo( nil, nil, QUEST_CONVO_HOOK.INTRO )
    :Loc{
        DIALOG_INTRO = [[
                * [p] A runner brought you a letter along with an invitation.
                * [p] It reads: Meet me in {diner#location}, I can make it worth your time.
        ]],
    }
    :State("START")
        :Fn(function(cxt)
            cxt:Dialog("DIALOG_INTRO")
        end)
QDEF:AddConvo( nil, nil, QUEST_CONVO_HOOK.ACCEPTED )
    :Loc{
        DIALOG_INTRO = [[
            player:
                !left
                [p] Well, it's worth a shot.
        ]],
    }
    :State("START")
        :Fn(function(cxt)
            cxt:Dialog("DIALOG_INTRO")
            
        end)
QDEF:AddConvo( nil, nil, QUEST_CONVO_HOOK.DECLINED )
    :Loc{
        DIALOG_INTRO = [[
            player:
                !left
                [p] This is clearly a scam.
        ]],
    }
    :State("START")
        :Fn(function(cxt)
            cxt:Dialog("DIALOG_INTRO")
        end)




FOLLOWUP = QDEF:AddFollowup()

FOLLOWUP:AddObjective{
    id = "wait",
    state = QSTATUS.ACTIVE,
    events = {
        do_sleep = function(quest)
            quest.param.ready = true
        end,
        morning_mail = function(quest, cxt)
            if quest.param.ready then
                quest.param.ready = false
                cxt:PlayQuestConvo( quest, "MorningMail" )
            end
        end,
    }
}

FOLLOWUP.on_init = function(quest)
    quest.param.regular_funds = math.floor(quest.param.funds / 2)
    quest:UnassignCastMember("diner")
end

FOLLOWUP:AddConvo(nil, nil, "MorningMail")
    :Loc{
        DIALOG_GOOD = [[
            * You received a mail in the morning.
            * It contains {regular_funds#money} and a message:
            * Here's your funding for the day. Keep up the good work!
            * Signed, {benefactor}.
        ]],
        DIALOG_BAD = [[
            * You received a mail in the morning.
            * It contains {regular_funds#money} and a message:
            * Due to your failing as a politician, I shall now stop funding your campaign.
            * This is the final money I will send you. After this, you will get nothing.
            * Signed, {benefactor}.
        ]]
    }
    :State("START")
        :Fn(function(cxt)
            if cxt.quest:GetCastMember("benefactor"):GetRelationship() > RELATIONSHIP.NEUTRAL then
                cxt:Dialog("DIALOG_GOOD")
                cxt.enc:GainMoney( cxt.quest.param.regular_funds )
            else
                cxt:Dialog("DIALOG_BAD")
                cxt.enc:GainMoney( cxt.quest.param.regular_funds )
                cxt.quest:Cancel()
            end
        end)