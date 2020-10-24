local ARTISTS = {
    RISE_PAMPHLETEER = 0.6,
    FOREMAN = 0.25,
    PRIEST = 0.5,
    SPARK_BARON_TASKMASTER = 0.25,
    ADMIRALTY_CLERK = 0.4,
    SPREE_CAPTAIN = 0.15,
    WEALTHY_MERCHANT = 0.25,
    POOR_MERCHANT = 0.35,
    JAKES_SMUGGLER = 0.2,
}
local function IsArtist(agent)
    return agent:CalculateProperty("IS_ARTIST", function(agent)
        local chance_for_artist = ARTISTS[agent:GetContentID()] or 0.1
        return math.random() < chance_for_artist
    end)
end

local QDEF = QuestDef.Define
{
    title = "Information Warfare",
    desc = "Commission someone for a propaganda poster and post it at popular locations to boost your campaign's popularity.",

    qtype = QTYPE.SIDE,
    act_filter = DemocracyUtil.DemocracyActFilter,
    focus = QUEST_FOCUS.NEGOTIATION,
    tags = {"RALLY_JOB"},
    reward_mod = 0,
    extra_reward = false,
    on_start = function(quest)
        quest:Activate("commission")
    end,
    precondition = function(quest)
        return TheGame:GetGameState():GetMainQuest():GetCastMember("primary_advisor")
    end,
}
:AddObjective{
    id = "commission",
    mark = function(quest, t, in_location)
        if in_location then
            local location = TheGame:GetGameState():GetPlayerAgent():GetLocation()
            for i, agent in location:Agents() do
                if DemocracyUtil.RandomBystanderCondition(agent) then
                    table.insert(t, agent)
                end
            end
        else
            DemocracyUtil.AddUnlockedLocationMarks(t)
        end
    end,
}
:AddObjective{
    id = "post",
}
DemocracyUtil.AddPrimaryAdvisor(QDEF, true)

QDEF:AddConvo("commission")
    :Loc{
        OPT_ASK_COMMISSION = "Commission {agent} for a propaganda poster",
        REQ_ALREADY_ASKED = "You already asked {agent.himher} once today.",
        DIALOG_ASK_COMMISSION = [[
            {not asked?
                player:
                    I'm looking to make a propaganda poster.
                    Can you help me make one?
                agent:
                {disliked?
                    Why should I?
                    If you want to make me help you, you have to pay.
                    A lot.
                }
                {not disliked?
                    {not is_artist?
                        I could certainly try.
                        Be warned: you probably will not like it.
                        You still have to pay for it though.
                    }
                    {is_artist?
                        Perhaps.
                        I can make you an extremely convincing poster.
                        Provided you can pay, of course.
                    }
                }
                player:
                    Name your price then.
                agent:
                    Okay.
                    If you can {demand_list#demand_list}, I will make a poster for you.
            }
            {asked?
                agent:
                    Have you decided yet?
            }
        ]],
        DIALOG_PAYED_COMMISSION = [[
            agent:
                Okay. You hold up your end of the bargain, I'll hold up mine.
                I'll make the poster for you.
                Now, what do you want it to say?
        ]],

        OPT_MAKE = "Make the poster yourself",
        DIALOG_MAKE = [[
            agent:
                You're really going to make it yourself?
            player:
                Well, yeah.
                It's a waste of money, really.
            agent:
                What happened to your funding?
                Did you spend it on drinking with people?
            player:
                Now that's none of your business.
            agent:
                Alright, keep your secrets then.
                Now, what do you want it to say?
        ]],
    }
    :Hub(function(cxt, who)
        if DemocracyUtil.RandomBystanderCondition(who) then
            cxt.enc.scratch.is_artist = IsArtist(who)
            if not cxt.quest.param.artist_demands then
                cxt.quest.param.artist_demands = {}
            end
            cxt.enc.scratch.asked = cxt.quest.param.artist_demands[who:GetID()] ~= nil
            cxt:Opt("OPT_ASK_COMMISSION")
                :SetQuestMark(cxt.quest)
                -- :ReqCondition(not who:HasMemoryFromToday("ASKED_FOR_COMMISSION"), "REQ_ALREADY_ASKED")
                :Fn(function(cxt)
                    if not cxt.quest.param.artist_demands[who:GetID()] then
                        local rawcost = 25 * cxt.quest:GetRank() + 25
                        if cxt.enc.scratch.is_artist then
                            rawcost = rawcost * 2
                        end
                        
                        local demands, demand_list = DemocracyUtil.GenerateDemandList(rawcost, who, nil, {
                            auto_scale = true,
                        })
                        cxt.quest.param.artist_demands[who:GetID()] = {
                            demands = demands,
                            demand_list = demand_list,
                        }
                    end

                    cxt.quest.param.demand_list = cxt.quest.param.artist_demands[who:GetID()].demand_list
                    -- DBG(cxt.enc.scratch.demand_list)
                    -- cxt.enc.scratch.testlol = true
                end)
                :Dialog("DIALOG_ASK_COMMISSION")
                :LoopingFn(function(cxt)
                    local dat = cxt.quest.param.artist_demands[who:GetID()]
                    local payed_all = DemocracyUtil.AddDemandConvo(cxt, dat.demand_list, dat.demands)

                    if payed_all then
                        cxt:Dialog("DIALOG_PAYED_COMMISSION")
                        cxt.quest.param.artist = who
                        cxt:GoTo("STATE_MAKE_POSTER")
                    else
                        StateGraphUtil.AddBackButton(cxt)
                    end
                end)
        elseif who == cxt.quest:GetCastMember("primary_advisor") then
            cxt:Opt("OPT_MAKE")
                :SetQuestMark(cxt.quest)
                :Dialog("DIALOG_MAKE")
                :GoTo("STATE_MAKE_POSTER")
        end
    end)
    :State("STATE_MAKE_POSTER")
        :Loc{
            OPT_HINT = "Ask about how to make posters",
            DIALOG_HINT = [[
                player:
                    Okay, I haven't actually made a poster before, and I'm not sure what to do.
                agent:
                    Now, making propaganda poster is like regular negotiation.
                    You can still use all your regular negotiation techniques.
                    However, once you've written it, you cannot change it.
                player:
                    So it's like a recording.
                agent:
                    More or less.
                    You might be tempted to write a lot, but people will be too intimidated by your wall of text.
                    Best to keep it short, but to the point.
            ]],

            OPT_START = "Start writing",

            DIALOG_START = [[
                player:
                    I'm ready to start.
                agent:
                    Excellent!
            ]],
        }
        :Fn(function(cxt)
            if not cxt.quest.param.cards then
                cxt.quest.param.cards = {}
            end
            cxt:Question("OPT_HINT", "DIALOG_HINT")
            -- yeah havent figured out what to do with it.
            cxt:Opt("OPT_START")
                :Dialog("DIALOG_START")
                :Negotiation{
                    
                }
        end)

QDEF:AddConvo( nil, nil, QUEST_CONVO_HOOK.INTRO )
    :Loc{
        DIALOG_INTRO = [[
            primary_advisor:
                Maybe it's a good idea to post propaganda posters in popular locations.
            player:
                We don't have anything like that, do we?
            primary_advisor:
                Not yet, anyway.
                You can ask someone to commission one for you.
            player:
                If I can't find anyone like that?
            primary_advisor:
                Then draw one yourself, or something.
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
                Sounds good.
                You know how to start?
            primary_advisor:
                Go ask someone who looks like they have artistic talents.
                !thought
                Or someone who looks like they have time to waste on art.
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
                I don't know. That might not worth the effort.
        ]],
    }
    :State("START")
        :Fn(function(cxt)
            cxt:Dialog("DIALOG_INTRO")
        end)