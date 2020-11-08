local INTERVIEWER_BEHAVIOR = {
    OnInit = function( self, difficulty )
        -- self.bog_boil = self:AddCard("bog_boil")
        local relationship_delta = self.agent and (self.agent:GetRelationship() - RELATIONSHIP.NEUTRAL) or 0
		self:SetPattern( self.BasicCycle )
        local modifier = self.negotiator:AddModifier("INTERVIEWER")
        -- modifier.agents = shallowcopy(self.agents)
        -- modifier:InitModifiers()
        self.cont_question_card = self:AddCard("contemporary_question_card")
        self.modifier_picker = self:MakePicker()
            :AddArgument("LOADED_QUESTION", 2 + math.max(0, -relationship_delta))
            :AddArgument("PLEASANT_QUESTION", 2 + math.max(0, relationship_delta))
            :AddArgument("GENERIC_QUESTION", 4)
            -- :AddCard(self.cont_question_card, 1)
        -- self.questions_answered = 0 -- jus to make sure
    end,
    available_issues = copyvalues(DemocracyConstants.issue_data),
    params = {},
	BasicCycle = function( self, turns )
		-- Double attack every 2 rounds; Single attack otherwise.
		if self.difficulty >= 4 and turns % 2 == 0 then
			self:ChooseGrowingNumbers( 3, -1 )
		elseif turns % 2 == 0 then
			self:ChooseGrowingNumbers( 2, 0 )
		else
			self:ChooseGrowingNumbers( 1, 1 )
        end
        -- if turns == 1 then
        --     self:ChooseGrowingNumbers( 1, 2 )
        -- end
        local question_count = 0
        for i, data in self.negotiator:Modifiers() do
            if data.AddressQuestion then
                question_count = question_count + 1
            end
        end
        if turns % 3 == 1 then
            self:ChooseCard(self.cont_question_card)
            if question_count < 4 then
                self.modifier_picker:ChooseCards(1)
            end
        -- elseif turns % 3 == 2 then
        --     self.modifier_picker:ChooseCards(2)
        else
            -- self:ChooseGrowingNumbers( 1, 1 )
            self.modifier_picker:ChooseCards(question_count < 4 and 2 or 1)
        end
	end,
}

local RELATION_OFFSET = {
    [RELATIONSHIP.HATED] = -20,
    [RELATIONSHIP.DISLIKED] = -10,
    [RELATIONSHIP.NEUTRAL] = 0,
    [RELATIONSHIP.LIKED] = 10,
    [RELATIONSHIP.LOVED] = 20,
}


local QDEF = QuestDef.Define
{
    title = "Interview",
    desc = "Do the interview and gain support.",
    icon = engine.asset.Texture("DEMOCRATICRACE:assets/quests/interview.png"),

    qtype = QTYPE.STORY,
    collect_agent_locations = function(quest, t)
        -- if quest:IsActive("return_to_advisor") then
        --     table.insert(t, { agent = quest:GetCastMember("primary_advisor"), location = quest:GetCastMember('home')})
        -- else
        table.insert(t, { agent = quest:GetCastMember("primary_advisor"), location = quest:GetCastMember('backroom'), role = CHARACTER_ROLES.VISITOR})
        -- end
        table.insert(t, { agent = quest:GetCastMember("host"), location = quest:GetCastMember('theater')})
    end,
    -- on_start = function(quest)

    -- end,
    -- on_complete = function(quest)
    --     if quest:GetCastMember("primary_advisor") then
    --         quest:GetCastMember("primary_advisor"):GetBrain():SendToWork()
    --     end
    -- end,
    on_destroy = function(quest)
        quest:GetCastMember("primary_advisor"):GetBrain():SendToWork()
        if quest.param.parent_quest then
            quest.param.parent_quest.param.did_interview = true
        end
    end,
}
:AddCast{
    cast_id = "host",
    cast_fn = function(quest, t) 
        if quest:GetCastMember("theater"):GetProprietor() then
            table.insert(t, quest:GetCastMember("theater"):GetProprietor())
        end
    end,
    when = QWHEN.MANUAL,
    events = 
    {
        agent_retired = function( quest, agent )
            -- if quest:IsActive( "get_snail" ) then
                -- If noodle chef died before we even got the snail, cast someone new.
                quest:UnassignCastMember( "host" )
                quest:AssignCastMember( "host" )
            -- end
        end,
    },
}
:AddCastFallback{
    cast_fn = function(quest, t)
        quest:GetCastMember("theater"):GetWorkPosition("host"):TryHire()
        if quest:GetCastMember("theater"):GetProprietor() then
            table.insert(t, quest:GetCastMember("theater"):GetProprietor())
        end
    end,
}
:AddLocationCast{
    cast_id = "theater",
    cast_fn = function(quest, t)
        table.insert(t, TheGame:GetGameState():GetLocation("GRAND_THEATER"))
    end,
    on_assign = function(quest, location)
        quest:SpawnTempLocation("BACKROOM", "backroom")
        quest:AssignCastMember("host")
    end,
    no_validation = true,
}
:AddLocationCast{
    cast_id = "backroom",
    no_validation = true,
    on_assign = function(quest, location)
        print(location)
        print(quest:GetCastMember("theater"))
        print(quest:GetCastMember("theater"):GetMapPos())
        location:SetMapPos( quest:GetCastMember("theater"):GetMapPos() )
    end,
    when = QWHEN.MANUAL,
}
:AddObjective{
    id = "go_to_interview",
    title = "Go to interview",
    desc = "Meet up with {primary_advisor} at the Grand Theater.",
    mark = {"backroom"},
    state = QSTATUS.ACTIVE,
}
:AddObjective{
    id = "do_interview",
    title = "Do the interview",
    desc = "Try not to embarrass yourself.",
    mark = {"theater"},
    -- state = QSTATUS.ACTIVE,
}
-- :AddObjective{
--     id = "return_to_advisor",
--     title = "Return to your advisor",
--     desc = "Return to your advisor and discuss your current situation.",
--     mark = {"primary_advisor"},
-- }

:AddLocationDefs{
    BACKROOM = {
        name = "Grand Theater Back Room",
        plax = "INT_Auction_Backroom_1",
        map_tags = {"city"},
        indoors = true,
    },
}

:AddOpinionEvents{
    likes_interview = {
        delta = OPINION_DELTAS.OPINION_UP,
        txt = "Likes your interview",
    },
    dislikes_interview = {
        delta = OPINION_DELTAS.TO_HATED,
        txt = "Dislikes your interview",
    }
}

DemocracyUtil.AddPrimaryAdvisor(QDEF, true)
DemocracyUtil.AddHomeCasts(QDEF)
QDEF:AddConvo("go_to_interview")
    :ConfrontState("STATE_CONFRONT", function(cxt) return cxt.location == cxt.quest:GetCastMember("backroom") end)
        :Loc{
            DIALOG_INTRO = [[
                * [p] You arrive at the Grand Theater, and are ushered into a back room. You barely make it into the room before you're ambushed by {primary_advisor}.
                player:
                    !left
                primary_advisor:
                    !right
                    Alright {player}, tonight is Big, so let's run through what you've got really quick.
                    Have you got you're prepared anwsers?
                player:
                    My what?
                primary_advisor:
                    Okay, no anwsers prepared...how about a teleprompter?
                player:
                    I have integrity, my dear {primary_advisor}!
                primary_advisor:
                    Yeah well integrity isn't going to get you through this in one piece
                    For Hesh's sake, did you even bring a breathmint?
                player:
                    Okay now that's just insulting.
                primary_advisor:
                    Well get ready for a lot more of that once you're on stage.
                    Think about it, kid. You're no longer a passer-by with a big mouth and big opinions.
                    This ain't little league anymore. This Interview is being broadcasted to all of Havaria.
                player:
                    !suprised
                    Really?
                primary_advisor:
                    Yes really! Hesh foresake those who don't stay to the shallows, don't you listen!
                player:
                    Well, look. let's focus on our inter-personal relationship AFTER I survive this.
                primary_advisor:
                    IF you survive, at this point, but true. Let's me give you the once over about the interview.
                * You and {primary_advisor} chatter about the interview, with them giving you pointers that make no sense to the task at hand.
                * Eventually, a worker calls for you, and you steel your nerves.
                player:
                    Moment of truth. Any last pointers?
                primary_advisor:
                    [P] If all else fails, sucker punch the interviewer and run.
                    player:
                    Gee, thanks.
            ]],
        }
        :Fn(function(cxt)
            cxt:Dialog("DIALOG_INTRO")
            cxt.quest:Complete("go_to_interview")
            cxt.quest:Activate("do_interview")
            cxt:Opt("OPT_LEAVE_LOCATION")
                :Fn(function(cxt)
                    cxt.encounter:DoLocationTransition(cxt.quest:GetCastMember("theater"))
                end)
                :MakeUnder()
        end)
QDEF:AddConvo("do_interview")
    :ConfrontState("STATE_CONFRONT", function(cxt) return cxt.location == cxt.quest:GetCastMember("theater") end)
        :Loc{
            DIALOG_INTRO = [[
                * [p] when you enter the room, you see a bunch of people
                * Looks liek lots of people wants to watch your interview.
                agent:
                    !right
                    let's welcome our special guest tonight, {player}!
                player:
                    !left
                * everyone clapped.
                * try to survive the interview, i guess?
            ]],
            OPT_DO_INTERVIEW = "Do the interview",
            SIT_MOD = "Has a lot of questions prepared for you.",

            DIALOG_INTERVIEW_SUCCESS = [[
                agent:
                    [p] once again, thank you for coming.
                player:
                    no problems.
                * phew! you survived the interview.
            ]],
            DIALOG_INTERVIEW_FAIL = [[
                player:
                    [p] i said something embarrassing and outrageous in front of everyone!
                * awkward silence.
                * oh no.
                * this embarrassment is going to cost you.
            ]],
            DIALOG_INTERVIEW_AFTER = [[
                * After the interview, {1*a person confronts you|several people confront you}.
            ]],
            DIALOG_INTERVIEW_AFTER_GOOD = [[
                * It seems a lot of people liked your interview! Nice!
            ]],
            DIALOG_INTERVIEW_AFTER_BAD = [[
                * That's not good. People don't like your interview!
            ]],
            OPT_ACCEPT_LOSS = "Accept your failure",
        }
        :Fn(function(cxt)
            cxt.enc:SetPrimaryCast(cxt.quest:GetCastMember("host"))
            cxt:Dialog("DIALOG_INTRO")
            cxt:GetAgent():SetTempNegotiationBehaviour(INTERVIEWER_BEHAVIOR)
            local agent_supports = {}
            for i, agent in cxt.quest:GetCastMember("theater"):Agents() do
                if agent:GetBrain():IsPatronizing() then
                    table.insert(agent_supports, {agent, DemocracyUtil.TryMainQuestFn("GetSupportForAgent", agent)})
                end
            end

            local function ResolvePostInterview()
                local agent_response = {}
                cxt.quest.param.num_likes = 0
                cxt.quest.param.num_dislikes = 0
                for i, data in ipairs(agent_supports) do
                    local current_support = DemocracyUtil.TryMainQuestFn("GetSupportForAgent", data[1])
                    local support_delta = current_support - data[2] + RELATION_OFFSET[data[1]:GetRelationship()] + math.random(-35, 15)
                    if support_delta > 20 then
                        table.insert(agent_response, {data[1], "likes_interview"})
                        cxt.quest.param.num_likes = cxt.quest.param.num_likes + 1
                    elseif support_delta < -20 then
                        table.insert(agent_response, {data[1], "dislikes_interview"})
                        cxt.quest.param.num_dislikes = cxt.quest.param.num_dislikes + 1
                    end
                end
                if #agent_response > 0 then
                    cxt:Dialog("DIALOG_INTERVIEW_AFTER", #agent_response)
                    for i, data in ipairs(agent_response) do
                        cxt.enc:PresentAgent(data[1], SIDE.RIGHT)
                        cxt:Quip(data[1], "post_interview", data[2])
                        data[1]:OpinionEvent(cxt.quest:GetQuestDef():GetOpinionEvent(data[2]))
                    end
                    if cxt.quest.param.num_likes - cxt.quest.param.num_dislikes >= 2 then
                        cxt:Dialog("DIALOG_INTERVIEW_AFTER_GOOD")
                        cxt.quest.param.good_interview = true
                        if cxt.quest.param.parent_quest then
                            cxt.quest.param.parent_quest.param.good_interview = true
                        end
                    elseif cxt.quest.param.num_likes - cxt.quest.param.num_dislikes <= -2 then
                        cxt:Dialog("DIALOG_INTERVIEW_AFTER_BAD")
                        cxt.quest.param.bad_interview = true
                        if cxt.quest.param.parent_quest then
                            cxt.quest.param.parent_quest.param.bad_interview = true
                        end
                    end
                end
            end
            cxt:Opt("OPT_DO_INTERVIEW")
                :Negotiation{
                    flags = NEGOTIATION_FLAGS.WORDSMITH,
                    situation_modifiers = {
                        { value = 20, text = cxt:GetLocString("SIT_MOD") }
                    },
                    on_success = function(cxt, minigame)
                        cxt:Dialog("DIALOG_INTERVIEW_SUCCESS")
                        -- TheGame:GetDebug():CreatePanel(DebugTable(INTERVIEWER_BEHAVIOR))
                        DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", (INTERVIEWER_BEHAVIOR.params.questions_answered or 0), "COMPLETED_QUEST")
                        -- Big calculations that happens.
                        ResolvePostInterview()
                        cxt.quest:Complete()
                        -- cxt.quest:Complete("do_interview")
                        -- cxt.quest:Activate("return_to_advisor")
                        StateGraphUtil.AddEndOption(cxt)
                    end,
                    on_fail = function(cxt)
                        cxt:Dialog("DIALOG_INTERVIEW_FAIL")
                        DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", -10)
                        ResolvePostInterview()
                        -- you can't recover from a failed interview. it's instant lose.
                        DemocracyUtil.AddAutofail(cxt, false)
                    end,
                }
        end)
-- TODO: Rework this
-- QDEF:AddConvo("return_to_advisor", "primary_advisor")
--     :AttractState("STATE_TALK")
--         :Loc{
--             DIALOG_INTRO = [[
--                 agent:
--                 {good_interview?
--                     [p] well done!
--                     im impressed by your work today.
--                 }
--                 {bad_interview?
--                     [p] i'm a bit disappointed by you.
--                     i can't believe you throw away a good opportunity like that.
--                 }
--                 {not (good_interview or bad_interview)?
--                     [p] you did good.
--                     hopefully that will be good enough.
--                 }
--                     !give
--                     here's your pay.
--             ]],
--             DIALOG_INTRO_PST = [[
--                 agent:
--                     [p] go to sleep when you're ready.
--                     i promise there's not going to be an assassin tonight.
--             ]],
--         }
--         :Fn(function(cxt)
--             cxt:Dialog("DIALOG_INTRO")
--             local money = DemocracyUtil.TryMainQuestFn("CalculateFunding")
--             cxt.enc:GainMoney(money)
--             if cxt.quest.param.good_interview and cxt.quest:GetCastMember("primary_advisor"):GetRelationship() < RELATIONSHIP.LOVED then
--                 cxt.quest:GetCastMember("primary_advisor"):OpinionEvent(cxt.quest:GetQuestDef():GetOpinionEvent("likes_interview"))
--             elseif cxt.quest.param.bad_interview and cxt.quest:GetCastMember("primary_advisor"):GetRelationship() > RELATIONSHIP.HATED then
--                 cxt.quest:GetCastMember("primary_advisor"):OpinionEvent(cxt.quest:GetQuestDef():GetOpinionEvent("dislikes_interview"))
--             end
--             cxt.quest:Complete()
--             cxt:Dialog("DIALOG_INTRO_PST")
--         end)
