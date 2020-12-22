local LocUnlock = require "DEMOCRATICRACE:content/get_location_unlock"
local fun = require "util/fun"
local negotiation_defs = require "negotiation/negotiation_defs"
local EVENT = negotiation_defs.EVENT

local battle_defs = require "battle/battle_defs"
local BATTLE_EVENT = battle_defs.BATTLE_EVENT

local RISE_DISGUISE_BUILDS = {
    -- DEFAULT = "LABORER",
    RISE_REBEL = "LABORER",
    RISE_REBEL_PROMOTED = "LABORER_PROMOTED",
    RISE_PAMPHLETEER = "LABORER",
    RISE_RADICAL = "HEAVY_LABORER",

}

local SPAWN_NAMED_CHAR = {
    FSSH = {workplace = "GROG_N_DOG", workpos = "bartender"},
    HESH_AUCTIONEER = {workplace = "GRAND_THEATER", workpos = "host"},
    HEBBEL = {workplace = "GB_NEUTRAL_BAR", workpos = "bartender"},
    SWEET_MOREEF = {workplace = "MOREEF_BAR", workpos = "bartender"},
    -- ENDO = {workplace = "MARKET_STALL", workpos = "negotiation_shop"},
    -- RAKE = {workplace = "MARKET_STALL", workpos = "battle_shop"},
    -- PLOCKA = {workplace = "MARKET_STALL", workpos = "graft_shop"},
    -- BEASTMASTER = {workplace = "MARKET_STALL", workpos = "beastmaster_shop"},
    
}
local function InitNamedChars()
    for id, data in pairs(SPAWN_NAMED_CHAR) do

        
        local agent = TheGame:GetGameState():GetAgentOrMemento( id )
        if not agent then
            print("Initializing: " .. id)
            agent = TheGame:GetGameState():AddSkinnedAgent(id)
        end
        local location = TheGame:GetGameState():GetLocation(data.workplace)
        if agent:GetBrain():GetWorkPosition() == nil and location then
            AgentUtil.TakeJob(agent, location, data.workpos)
            -- agent:GetBrain():SetHome(location)
        end
    end
end

local DAY_SCHEDULE = {
    {quest = "RACE_DAY_1", difficulty = 1, support_expectation = {0,10,25}},
    {quest = "RACE_DAY_2", difficulty = 2, support_expectation = {25,40,55,70}},
    {quest = "RACE_DAY_3", difficulty = 3, support_expectation = {70,90,115,140}},
    -- {quest = "RACE_DAY_4", difficulty = 4},
    -- {quest = "RACE_DAY_5", difficulty = 5},
}
local MAX_DAYS = #DAY_SCHEDULE-- 5

------------------------------------------------------------------------------------------------

-- Determines the support level change when an agent's relationship changes.
-- The general support changes by this amount, while the faction and wealth support changes by double this amount.
local DELTA_SUPPORT = {
    [RELATIONSHIP.LOVED] = 6,
    [RELATIONSHIP.LIKED] = 3,
    [RELATIONSHIP.NEUTRAL] = 0,
    [RELATIONSHIP.DISLIKED] = -3,
    [RELATIONSHIP.HATED] = -6,
}
-- Determines the support level change when an agent is killed.
local DEATH_DELTA = -10

-- Determines the support level change when an agent is killed in an isolated scenario.
-- Still reduce support, but people won't know for sure it's you.
local ISOLATED_DEATH_DELTA = -2

-- Determines the support change if you didn't kill someone, but you're an accomplice
-- or someone dies from neglegience
local ACCOMPLICE_KILLING_DELTA = -5
local QDEF = QuestDef.Define
{
    title = "The Democratic Race",
    -- icon = engine.asset.Texture("icons/quests/sal_story_act1_huntingkashio.tex"),
    qtype = QTYPE.STORY,
    desc = "Become the president as you run a democratic campaign.",
    icon = engine.asset.Texture("DEMOCRATICRACE:assets/quests/main_icon.png"),

    max_day = MAX_DAYS,
    get_narrative_progress = function(quest)
        
        local total_days = MAX_DAYS
        local completed_days = (quest.param.day or 1)-1

        local sub_day_progress = (quest.param.sub_day_progress or 1) - 1
        local max_subdays = #(quest:DefFn("GetCurrentExpectationArray"))

        local percent = (completed_days + sub_day_progress / max_subdays) / total_days
        local title = loc.format(LOC "CALENDAR.DAY_FMT", quest.param.day or 1)
        return percent, title, quest.param.day_quest and quest.param.day_quest:GetTitle() or ""
    end,
    on_init = function(quest)

        TheGame:GetGameState():SetMainQuest(quest)
        -- TheGame:GetGameState():SetRollbackThresh(1)
        InitNamedChars()
        TheGame:GetGameState():GetCaravan():MoveToLocation(TheGame:GetGameState():GetLocation("MURDERBAY_NOODLE_SHOP"))
        
        -- TheGame:GetGameState():AddLocation(Location("DIPL_PRES_OFFICE"))
        -- TheGame:GetGameState():AddLocation(Location("MANI_PRES_OFFICE"))
        -- TheGame:GetGameState():AddLocation(Location("HOST_PRES_OFFICE"))
        -- The level of which people support you. All the indifferent characters may or may not
        -- vote for you, depending on your support level.
        -- Also they determine a whole bunch of things. Very important to keep high.
        -- Just read the README
        quest.param.support_level = 0
        -- Your support among factions.
        -- This is stored as the support relative to the general support
        -- The displayed support level is already adjusted.
        quest.param.faction_support = {}
        -- Your support level among wealth levels.(renown levels)
        quest.param.wealth_support = {}
        -- The locations you've unlocked.
        quest.param.unlocked_locations = --shallowcopy(Content.GetWorldRegion("democracy_pearl").locations)--{"MURDERBAY_NOODLE_SHOP"}
        {"MURDERBAY_NOODLE_SHOP"}
        
        -- quest.param.free_time_actions = 1

        quest.param.stances = {}
        quest.param.stance_change = {}
        quest.param.stance_change_freebie = {}

        local new_faction_relationships = {
            {"BANDITS", "SPARK_BARONS", RELATIONSHIP.DISLIKED},
            {"BANDITS", "CULT_OF_HESH", RELATIONSHIP.DISLIKED},
            {"BANDITS", "FEUD_CITIZEN", RELATIONSHIP.DISLIKED},
            {"SPARK_BARONS", "CULT_OF_HESH", RELATIONSHIP.HATED},
            {"ADMIRALTY", "RISE", RELATIONSHIP.HATED},
            -- {"BANDITS", "RISE", RELATIONSHIP.DISLIKED},
            {"BANDITS", "JAKES", RELATIONSHIP.LIKED},
            {"ADMIRALTY", "CULT_OF_HESH", RELATIONSHIP.LIKED},
            {"ADMIRALTY", "SPARK_BARONS", RELATIONSHIP.LIKED},
            {"JAKES", "SPARK_BARONS", RELATIONSHIP.LIKED},
            {"JAKES", "ADMIRALTY", RELATIONSHIP.NEUTRAL},
            {"JAKES", "CULT_OF_HESH", RELATIONSHIP.DISLIKED},
            {"FEUD_CITIZEN", "RISE", RELATIONSHIP.LIKED},
        }
        for i, data in ipairs(new_faction_relationships) do
            TheGame:GetGameState():GetFactions():SetFactionRelationship(table.unpack(data))
        end

        -- quest.param.allow_skip_side = true

        -- TheGame:GetGameState():GetPlayerAgent().graft_owner:AddGraft(GraftInstance("relation_support_tracker"))

        QuestUtil.StartDayQuests(DAY_SCHEDULE, quest)

        if quest.param.start_on_day and quest.param.start_on_day >= 2 then
            quest:AssignCastMember("primary_advisor", quest:GetCastMember(quest.param.force_advisor_id or table.arraypick(DemocracyUtil.ADVISOR_IDS)))
            QuestUtil.SpawnQuest("RACE_LIVING_WITH_ADVISOR")
            quest:DefFn("DeltaGeneralSupport", (quest.param.init_support_level or 0) * (quest.param.start_on_day - 1))
        end
        QuestUtil.SpawnQuest("CAMPAIGN_SHILLING")
        QuestUtil.SpawnQuest("CAMPAIGN_RANDOM_COIN_FIND")

        QuestUtil.SpawnQuest("SAL_STORY_MERCHANTS")
        -- populate all locations.
        -- otherwise there's a lot of bartenders attending the first change my mind quest for some dumb reason.
        for i, location in TheGame:GetGameState():AllLocations() do
            LocationUtil.PopulateLocation( location )
        end
        QuestUtil.DoNextDay(DAY_SCHEDULE, quest, quest.param.start_on_day )
        
        DoAutoSave()
    end,
    plot_armour_fn = function(quest, agent)
        return agent:IsCastInQuest(quest)
    end,
    events = 
    {
        -- GAME_OVER = function( self, gamestate, result )
        --     if result == GAMEOVER.VICTORY then
        --         TheGame:GetGameProfile():AcquireUnlock("DONE_POLITICS_BEFORE")
        --         print("YAY we did it!")
        --     end
        -- end,
        agent_location_changed = function(quest, agent, old_loc, new_loc)
            -- if event == "agent_location_changed" then
                print("location change triggered")
                local disguise = RISE_DISGUISE_BUILDS[agent:GetContentID()]
                if disguise then
                    print("Has disguise yay!" .. disguise)
                    if DemocracyUtil.IsWorkplace(new_loc) or new_loc:GetContentID() == "GB_LABOUR_OFFICE" then
                        local new_build = Content.GetCharacterDef(disguise).base_builds[agent.gender]
                        if new_build then
                            agent:SetBuildOverride(new_build)
                        end
                    else
                        agent:SetBuildOverride()
                    end
                end
            -- end
        end,
        agent_relationship_changed = function( quest, agent, old_rel, new_rel )
            if agent == quest:GetCastMember("primary_advisor") then
                return
            end
            local support_delta = DELTA_SUPPORT[new_rel] - DELTA_SUPPORT[old_rel]
            if support_delta ~= 0 then
                quest:DefFn("DeltaAgentSupport", support_delta, agent, support_delta > 0 and "RELATIONSHIP_UP" or "RELATIONSHIP_DOWN")
            end
            -- if new_rel == RELATIONSHIP.LOVED and old_rel ~= RELATIONSHIP.LOVED then
            --     TheGame:GetGameState():GetCaravan():DeltaMaxResolve(1)
            -- end
        end,
        card_added = function( quest, card )
            if card.murder_card then
                quest:DefFn("DeltaGeneralSupport", DEATH_DELTA, "MURDER")
            end
        end,
        resolve_battle = function( quest, battle, primary_enemy, repercussions )
            for i, fighter in battle:AllFighters() do
                local agent = fighter.agent
                if agent:IsSentient() and agent:IsDead() then
                    if CheckBits( battle:GetScenario():GetFlags(), BATTLE_FLAGS.ISOLATED ) then
                        quest:DefFn("DeltaAgentSupport", ISOLATED_DEATH_DELTA, agent, "SUSPICION")
                    elseif fighter:GetKiller() and fighter:GetKiller():IsPlayer() then
                        -- killing already comes with a heavy drawback of someone hating you, thus reducing support significantly.
                        -- quest:DefFn("DeltaAgentSupport", DEATH_DELTA, agent, "MURDER")
                    else
                        if fighter:GetTeamID() == TEAM.BLUE then
                            quest:DefFn("DeltaAgentSupport", ACCOMPLICE_KILLING_DELTA, agent, "NEGLIGENCE")
                        else
                            quest:DefFn("DeltaAgentSupport", ACCOMPLICE_KILLING_DELTA, agent, "ACCOMPLICE")
                        end
                    end
                end
            end
            if not CheckBits( battle:GetScenario():GetFlags(), battle_defs.BATTLE_FLAGS.SELF_DEFENCE ) then
                -- Being aggressive hurts your reputation
                DemocracyUtil.TryMainQuestFn("DeltaGeneralSupport", -5, "ATTACK")
            end
        end,
        action_clock_advance = function(quest, location)
            quest.param.event_delays = (quest.param.event_delays or 0) + 1
            if math.random() < 0.12 * (quest.param.event_delays - 1) then
                TheGame:GetGameState():AddPendingEvent()
                quest.param.event_delays = 0
            end
        end,
        quests_changed = function(quest, event_quest)
            if event_quest:GetQuestDef():HasTag( "REQUEST_JOB" ) and event_quest:IsComplete() then
                TheGame:AddGameplayStat( "completed_request_quest", 1 )
            end
            if event_quest == quest.param.day_quest and quest.param.day_quest:IsComplete() then
                DemocracyUtil.EndFreeTime()
                if quest.param.day then
                    TheGame:AddGameplayStat( "democracy_day_" .. quest.param.day, 1 )
                end
                QuestUtil.DoNextDay(DAY_SCHEDULE, quest)
            end
        end,
    },
    SpawnPoolJob = function(quest, pool_name, excluded_ids, spawn_as_inactive, spawn_as_challenge)
        local event_id = pool_name
        local attempt_quest_ids = {}
        local all_quest_ids = {}
        excluded_ids = excluded_ids or {}
        for k, questdef in pairs( Content.GetAllQuests() ) do
            if questdef:HasTag(pool_name) and questdef.id ~= quest.param.recent_side_id then
                if not table.arraycontains(excluded_ids, questdef.id) then
                    table.insert(attempt_quest_ids, questdef.id)
                end
                table.insert(all_quest_ids, questdef.id)
            end
        end
        -- DBG(attempt_quest_ids)
        -- if #attempt_quest_ids == 0 then
        --     attempt_quest_ids = all_quest_ids
        -- end
        -- assert(#attempt_quest_ids > 0, "No quests available")

        local quest_scores = {}
        for k,v in ipairs(all_quest_ids) do
            quest_scores[v] = QuestUtil.CalcQuestSpawnScore(event_id, math.floor(#all_quest_ids/2), v) + math.random(1,5)
            if TheGame:GetGameState():GetQuestActivatedCount(v) > 0 then
                quest_scores[v] = quest_scores[v] - 7
            end
        end
        table.shuffle(attempt_quest_ids) --to mix up the case where there are a lot of ties
        table.stable_sort(attempt_quest_ids, function(a,b) return quest_scores[a] < quest_scores[b] end)
        local new_quest
        for _, quest_id in ipairs(attempt_quest_ids) do
            local overrides = {qrank = TheGame:GetGameState():GetCurrentBaseDifficulty() + (spawn_as_challenge and 1 or 0)}
            
            if spawn_as_inactive then
                new_quest = QuestUtil.SpawnInactiveQuest( quest_id, overrides) 
            else
                new_quest = QuestUtil.SpawnQuest( quest_id, overrides) 
            end
        
            if new_quest then
                if quest.param.day == 1 then
                    new_quest.upfront_reward = true
                end
                TheGame:GetGameProfile():RecordIncident(event_id, new_quest:GetContentID())
                return new_quest
            end
        end

        if not new_quest then
            table.shuffle(all_quest_ids)
            table.stable_sort(all_quest_ids, function(a,b) return quest_scores[a] < quest_scores[b] end)
            for _, quest_id in ipairs(all_quest_ids) do
                local overrides = {qrank = TheGame:GetGameState():GetCurrentBaseDifficulty() + (spawn_as_challenge and 1 or 0)}
                
                if spawn_as_inactive then
                    new_quest = QuestUtil.SpawnInactiveQuest( quest_id, overrides) 
                else
                    new_quest = QuestUtil.SpawnQuest( quest_id, overrides) 
                end
            
                if new_quest then
                    if quest.param.day == 1 then
                        new_quest.upfront_reward = true
                    end
                    TheGame:GetGameProfile():RecordIncident(event_id, new_quest:GetContentID())
                    return new_quest
                end
            end
        end

        return new_quest
    end,
    -- Offer jobs at certain point of the story.
    -- probably should always call this.
    OfferJobs = function(quest, cxt, job_num, pool_name, allow_challenge, can_skip)
        local jobs = {}
        local used_ids = {}
        if cxt.enc.scratch.job_pool then
            jobs = cxt.enc.scratch.job_pool
        else
            for k = 1, job_num do
                local new_job = quest:DefFn("SpawnPoolJob", pool_name, used_ids, true, k == 1 and allow_challenge)
                if new_job then
                    table.insert(used_ids, new_job:GetContentID())
                    table.insert(jobs, new_job)
                end
            end
            cxt.enc.scratch.job_pool = jobs
        end
        DemocracyUtil.PresentJobChoice(cxt, jobs, function(cxt)
            if can_skip == true or (quest.param.allow_skip_side and can_skip ~= false) then
                cxt:Opt("OPT_SKIP_RALLY")
                    :MakeUnder()
                    :Dialog("DIALOG_CHOOSE_FREE_TIME")
                    :Fn(function(cxt)
                        cxt:Opt("OPT_INSIST_FREE_TIME")
                            :PreIcon(global_images.accept)
                            :Dialog("DIALOG_INSIST_FREE_TIME")
                            :Fn(function(cxt)
                                cxt.quest.param.current_job = "FREE_TIME"
                                cxt.quest:Complete("get_job")
                                -- cxt.quest:Activate("do_job")
                                --cxt:PlayQuestConvo(cxt.quest.param.job, QUEST_CONVO_HOOK.INTRO)
                                StateGraphUtil.AddEndOption(cxt)
                            end)
                        cxt:Opt("OPT_NEVER_MIND")
                            :PreIcon(global_images.reject)
                            :Dialog("DIALOG_NEVER_MIND_FREE_TIME")
                    end)
            end
        end, function(cxt, jobs_presented, job_picked) 
            cxt.quest.param.current_job = job_picked
            quest.param.recent_side_id = job_picked:GetContentID()
            cxt.quest:Complete("get_job")
            -- cxt.quest:Activate("do_job")
            --cxt:PlayQuestConvo(cxt.quest.param.job, QUEST_CONVO_HOOK.INTRO)
            StateGraphUtil.AddEndOption(cxt)
        end)
        
    end,
    DeltaSupport = function(quest, amt, target, notification)
        local type, t = DemocracyUtil.DetermineSupportTarget(target)
        if type == "FACTION" then
            quest:DefFn("DeltaFactionSupport", amt, t, notification)
        elseif type == "WEALTH" then
            quest:DefFn("DeltaWealthSupport", amt, t, notification)
        else
            quest:DefFn("DeltaGeneralSupport", amt, notification)
        end
    end,
    DeltaGeneralSupport = function(quest, amt, notification)
        quest.param.support_level = (quest.param.support_level or 0) + amt
        if notification == nil then
            notification = true
        end
        if notification and amt ~= 0 then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_GENERAL_SUPPORT, amt, quest:DefFn("GetGeneralSupport"), notification ) 
        end
        if amt > 0 then
            TheGame:AddGameplayStat( "gained_general_support", amt )
        end
    end,
    DeltaFactionSupport = function(quest, amt, faction, notification)
        faction = DemocracyUtil.ToFactionID(faction)
        quest.param.faction_support[faction] = (quest.param.faction_support[faction] or 0) + amt
        if notification == nil then
            notification = true
        end
        if notification and amt ~= 0 then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_FACTION_SUPPORT, amt, quest:DefFn("GetFactionSupport", faction), TheGame:GetGameState():GetFaction(faction), notification ) 
        end
        if amt > 0 then
            TheGame:AddGameplayStat( "gained_faction_support_" .. faction, amt )
        end
    end,
    DeltaWealthSupport = function(quest, amt, renown, notification)
        local r = DemocracyUtil.GetWealth(renown)
        quest.param.wealth_support[r] = (quest.param.wealth_support[r] or 0) + amt
        if notification == nil then
            notification = true
        end
        if notification and amt ~= 0 then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_WEALTH_SUPPORT, amt, quest:DefFn("GetWealthSupport", r), r, notification ) 
        end
        if amt > 0 then
            TheGame:AddGameplayStat( "gained_wealth_support_" .. r, amt )
        end
    end,

    DeltaAgentSupport = function(quest, amt, agent, notification)
        quest:DefFn("DeltaGeneralSupport", amt, false)
        quest:DefFn("DeltaFactionSupport", amt, agent, false)
        quest:DefFn("DeltaWealthSupport", amt, agent, false)
        if notification == nil then
            notification = true
        end
        if notification and amt then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_AGENT_SUPPORT, amt, agent, notification ) 
        end
    end,
    -- DeltaFactionSupportAgent = function(quest, amt, agent, ignore_notification)
    --     quest:DefFn("DeltaFactionSupport", amt, agent:GetFactionID(), ignore_notification)
    -- end,
    -- DeltaWealthSupportAgent = function(quest, amt, agent, ignore_notification)
    --     quest:DefFn("DeltaWealthSupport", amt, agent:GetRenown() or 1, ignore_notification)
    -- end,
    DeltaGroupFactionSupport = function(quest, group_delta, multiplier, notification)
        multiplier = multiplier or 1
        if notification == nil then
            notification = true
        end
        local actual_group = {}
        for id, val in pairs(group_delta or {}) do
            actual_group[id] = math.round(val * multiplier)
            quest:DefFn("DeltaFactionSupport", actual_group[id], id, false)
        end
        if notification then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_GROUP_FACTION_SUPPORT, actual_group, notification)
        end
    end,
    DeltaGroupWealthSupport = function(quest, group_delta, multiplier, notification)
        multiplier = multiplier or 1
        if notification == nil then
            notification = true
        end
        local actual_group = {}
        for id, val in pairs(group_delta or {}) do
            actual_group[id] = math.round(val * multiplier)
            quest:DefFn("DeltaWealthSupport", math.round(val * multiplier), id, false)
        end
        if notification then
            TheGame:GetGameState():LogNotification( NOTIFY.DELTA_GROUP_WEALTH_SUPPORT, actual_group, notification)
        end
    end,
    -- Getters
    GetGeneralSupport = function(quest) return quest.param.support_level end,
    GetFactionSupport = function(quest, faction)
        faction = DemocracyUtil.ToFactionID(faction)
        return quest.param.support_level + (quest.param.faction_support[faction] or 0)
    end,
    GetWealthSupport = function(quest, renown)
        local r = DemocracyUtil.GetWealth(renown)
        return quest.param.support_level + (quest.param.wealth_support[r] or 0)
    end,
    GetCompoundSupport = function(quest, faction, renown)
        faction = DemocracyUtil.ToFactionID(faction)
        return quest.param.support_level + (quest.param.faction_support[faction] or 0) + (quest.param.wealth_support[DemocracyUtil.GetWealth(renown)] or 0)
    end,
    -- GetFactionSupportAgent = function(quest, agent)
    --     return quest:DefFn("GetFactionSupport", agent:GetFactionID())
    -- end,
    -- GetWealthSupportAgent = function(quest, agent)
    --     return quest:DefFn("GetWealthSupport", agent:GetRenown() or 1)
    -- end,
    GetSupportForAgent = function(quest, agent)
        return quest:DefFn("GetCompoundSupport", agent:GetFactionID(), agent:GetRenown() or 1)
    end,
    -- At certain points in the story, random peope dislikes you for no reason.
    -- call this function to do so.
    DoRandomOpposition = function(quest, num_to_do)
        num_to_do = num_to_do or 1
        for i = 1, num_to_do do
            if quest:GetCastMember("random_opposition") then
                quest:UnassignCastMember("random_opposition")
            end
            quest:AssignCastMember("random_opposition")
            quest:GetCastMember("random_opposition"):OpinionEvent(OPINION.DISLIKE_IDEOLOGY)
            quest:UnassignCastMember("random_opposition")
        end
    end,

    -- Calculate the funding level for the day using this VERY scientific calculation based on wealth support.
    CalculateFunding = function(quest, rate)
        rate = rate or 1
        local money = 0
        for i = 1, DemocracyConstants.wealth_levels do
            money = money + quest:DefFn("GetWealthSupport", i) * i
        end
        money = money / 8
        money = money + 100
        money = math.max(0, money)
        return math.round(money * rate)
    end,
    -- Just handle the change in stance and consistency of your opinion.
    -- Does not handle the relationship gained from updating your stance.
    UpdateStance = function(quest, issue, val, strict, autosupport)
        if type(issue) == "table" then
            issue = issue.id
        end
        -- local multiplier = type(autosupport) == "number" and autosupport or 1
        if autosupport == nil then
            autosupport = true
        end
        -- multiplier = multiplier or 1
        if quest.param.stances[issue] == nil then
            quest.param.stances[issue] = val
            quest.param.stance_change[issue] = 0
            quest.param.stance_change_freebie[issue] = not strict
            TheGame:GetGameState():LogNotification( NOTIFY.UPDATE_STANCE, issue, val, strict )
        else
            local stance_delta = val - quest.param.stances[issue]
            if stance_delta == 0 or (not strict and (quest.param.stances[issue] > 0) == (val > 0) and (quest.param.stances[issue] < 0) == (val < 0)) then
                -- A little bonus for being consistent with your ideology.
                quest:DefFn("DeltaGeneralSupport", 1, "CONSISTENT_STANCE")
                quest.param.stance_change[issue] = math.max(0, quest.param.stance_change[issue] - 1)
                quest.param.stance_change_freebie[issue] = false
            else
                if quest.param.stance_change_freebie[issue] 
                    and (quest.param.stances[issue] > 0) == (val > 0) 
                    and (quest.param.stances[issue] < 0) == (val < 0) then

                    quest:DefFn("DeltaGeneralSupport", 1, "CONSISTENT_STANCE")
                    quest.param.stance_change[issue] = math.max(0, quest.param.stance_change[issue] - 1)
                    -- quest.param.stances[issue] = val
                else
                    -- Penalty for being inconsistent.
                    quest.param.stance_change[issue] = quest.param.stance_change[issue] + math.abs(stance_delta)
                    quest:DefFn("DeltaGeneralSupport", -math.max(0, quest.param.stance_change[issue]), "INCONSISTENT_STANCE")
                end
                quest.param.stances[issue] = val
                quest.param.stance_change_freebie[issue] = not strict
                TheGame:GetGameState():LogNotification( NOTIFY.UPDATE_STANCE, issue, val, strict )
            end
        end
        if autosupport then
            local multiplier = type(autosupport) == "number" and autosupport or 1
            local issue_data = DemocracyConstants.issue_data[issue]
            if issue_data then
                local stance = issue_data.stances[val]
                if stance.faction_support then
                    DemocracyUtil.TryMainQuestFn("DeltaGroupFactionSupport", stance.faction_support, multiplier)
                end
                if stance.wealth_support then
                    DemocracyUtil.TryMainQuestFn("DeltaGroupWealthSupport", stance.wealth_support, multiplier)
                end
            end
        end
        print(loc.format("Updated stance: '{1}': {2}(strict: {3})", issue, val, strict))
        
    end,
    GetStance = function(quest, issue)
        if type(issue) == "table" then
            issue = issue.id
        end
        return quest.param.stances[issue]
    end,
    GetStanceChange = function(quest, issue)
        if type(issue) == "table" then
            issue = issue.id
        end
        return quest.param.stance_change[issue]
    end,
    GetStanceChangeFreebie = function(quest, issue)
        if type(issue) == "table" then
            issue = issue.id
        end
        return quest.param.stance_change_freebie[issue]
    end,

    SetSubdayProgress = function(quest, progress)
        quest.param.sub_day_progress = progress
    end,
    GetCurrentExpectationArray = function(quest)
        return DAY_SCHEDULE[math.min(#DAY_SCHEDULE, quest.param.day or 1)].support_expectation
    end,
    GetCurrentExpectation = function(quest)
        local arr = quest:DefFn("GetCurrentExpectationArray")
        return arr[math.min(#arr, quest.param.sub_day_progress or 1)] -- - 100
    end,

    -- debug functions
    DebugUnlockAllLocations = function(quest)
        quest.param.unlocked_locations = shallowcopy(Content.GetWorldRegion("democracy_pearl").locations)
        print(loc.format("Unlocked all locations ({1} total)", #quest.param.unlocked_locations))
    end,
}
:AddCast{
    cast_id = "random_opposition",
    when = QWHEN.MANUAL,
    score_fn = DemocracyUtil.OppositionScore,
    condition = function(agent, quest)
        if agent:GetRelationship() == RELATIONSHIP.DISLIKED then
            return math.random() < 0.1 -- sometimes we allow disliked people to hate you.
        end
        return agent:GetRelationship() < RELATIONSHIP.LOVED and agent:GetRelationship() > RELATIONSHIP.DISLIKED
    end,
}
:AddCastFallback{
    cast_fn = function(quest, t)
        table.insert( t, quest:CreateSkinnedAgent() )
    end,
}
:AddCast{
    cast_id = "primary_advisor",
    when = QWHEN.MANUAL,
    no_validation = true,
    on_assign = function(quest,agent)
        quest:AssignCastMember("home")
        if quest.param.all_day_quests then
            for k,v in ipairs(quest.param.all_day_quests) do
                if v:GetQuestDef():GetCast("primary_advisor") then
                    v:AssignCastMember("primary_advisor", quest:GetCastMember("primary_advisor"))
                end
            end
        end
    end,
}
-- :AddCastByAlias{
--     -- Let fssh be the bartender of grog n dog
--     cast_id = "fssh",
--     alias = "FSSH",
--     on_assign = function(quest, agent)
--         local location = TheGame:GetGameState():GetLocation("GROG_N_DOG")
--         if agent:GetBrain():GetWorkPosition() == nil and location then
--             AgentUtil.TakeJob(agent, location, "bartender")
--             -- agent:GetBrain():SetHome(location)
--         end
--     end,
-- }
-- :AddCastByAlias{
--     cast_id = "host",
--     alias = "HESH_AUCTIONEER",
--     on_assign = function(quest, agent)
--         local location = TheGame:GetGameState():GetLocation("GRAND_THEATER")
--         if agent:GetBrain():GetWorkPosition() == nil and location then
--             AgentUtil.TakeJob(agent, location, "host")
--             -- agent:GetBrain():SetHome(location)
--         end
--         quest:UnassignCastMember("host")
--     end,
--     optional = true,
-- }
-- Have to do this to make plot_armour_fn work.
:AddObjective{
    id = "start",
    state = QSTATUS.ACTIVE,
}

DemocracyUtil.AddAdvisors(QDEF)
DemocracyUtil.AddHomeCasts(QDEF)
DemocracyUtil.AddOppositionCast(QDEF)

-- A fail safe. Once you've been to a unlockable location that hasn't been unlocked, you unlock it.
QDEF:AddConvo()
    :Priority(CONVO_PRIORITY_HIGHEST)
    :ConfrontState("STATE_UNLOCK", function(cxt)
        local id = cxt.location:GetContentID()
        return id and table.arraycontains(LocUnlock.ALL_LOCATION_UNLOCKS, id) 
            and not DemocracyUtil.LocationUnlocked(id)
    end)
    :Loc{
        DIALOG_NEW_LOCATION = [[
            * You've never been here before. Nice!
            * After you're done with this ordeal, you can visit this location during your free time.
        ]]
    }
    :Fn(function(cxt)
        cxt:Dialog("DIALOG_NEW_LOCATION")
        DemocracyUtil.DoLocationUnlock(cxt, cxt.location:GetContentID())
    end)

QDEF:AddDebugOption("start_on_day", {1,2})
    :AddDebugOption(
        "force_advisor_id",
        copykeys(DemocracyUtil.ADVISOR_IDS),
        function(param) return param.start_on_day and param.start_on_day >= 2 end
    )
    :AddDebugOption(
        "init_support_level",
        {0,10,15,20,25,30,40},
        function(param) return param.start_on_day and param.start_on_day >= 2 end
    )