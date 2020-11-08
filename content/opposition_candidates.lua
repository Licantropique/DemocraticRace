local t = {
    candidate_admiralty = {
        cast_id = "candidate_admiralty",
        character = "MURDER_BAY_ADMIRALTY_CONTACT",
        workplace = "ADMIRALTY_BARRACKS",
        
        -- main = "Security for all",
        -- desc = "Oolo plans to improve the safety of Havaria by improving the security. Powered by the Admiralty, of course. Popular among middle class who cannot afford private security, not popular among upper class(because of increased tax rate) and lower class.",
        platform = "SECURITY",
        stances = {
            SECURITY = 2,
            INDEPENDENCE = -2,
        },
        faction_support = {
            ADMIRALTY = 3,
            FEUD_CITIZEN = 2,
            BANDITS = -3,
            RISE = -2,
            -- SPARK_BARONS = -1,
            CULT_OF_HESH = 1,
            JAKES = -1,
        },
        wealth_support = {
            -2,
            2,
            1,
            -1,
        },
    },
    candidate_spree = {
        cast_id = "candidate_spree",
        character = "MURDER_BAY_BANDIT_CONTACT",
        workplace = "SPREE_INN",

        platform = "INDEPENDENCE",

        stances = {
            SECURITY = -2,
            INDEPENDENCE = 2,
        },
        -- main = "Havaria Independence",
        -- desc = "Nadan wants to cut the ties of Havaria with Deltree. Popular among poorer people, but unpopular among the rich, Admiralty, and the Cult.",
        faction_support = {
            ADMIRALTY = -3,
            FEUD_CITIZEN = 1,
            BANDITS = 3,
            -- RISE = -1,
            SPARK_BARONS = -1,
            CULT_OF_HESH = -2,
            JAKES = 2,
        },
        wealth_support = {
            -2,
            -1,
            1,
            2,
        },
    },
    candidate_baron = {
        cast_id = "candidate_baron",
        character = "SPARK_CONTACT",
        workplace = "GB_BARON_HQ",

        -- main = "Tax cut",
        -- desc = "Reduce taxes for all. That's it. That's their plan. Fellemo isn't really that bright. Popular among rich people(and some poor people), but unpopular among those who care about equality and those who have plans for utilizing the taxes.",
        platform = "TAX_POLICY",

        stances = {
            TAX_POLICY = -2,
        },
        
        faction_support = {
            ADMIRALTY = -3,
            FEUD_CITIZEN = 1,
            -- BANDITS = 1,
            RISE = -1,
            SPARK_BARONS = 3,
            CULT_OF_HESH = -2,
            JAKES = 2,
        },
        wealth_support = {
            1,
            -2,
            -1,
            2,
        },
    },
    candidate_rise = {
        cast_id = "candidate_rise",
        character = "KALANDRA",
        workplace = "GB_LABOUR_OFFICE",
        -- main = "Universal Rights",
        -- desc = "Grant rights to every citizen of Havaria, I don't know, read the Declaration of Rights or something. That mostly means slavery is illegal! Popular among the workers, but unpopular among the Cult, Barons, and all those who exploit the labour of the people.",
        platform = "LABOR_LAW",

        stances = {
            LABOR_LAW = 1,
        },
        faction_support = {
            ADMIRALTY = -1,
            FEUD_CITIZEN = 2,
            -- BANDITS = ,
            RISE = 3,
            SPARK_BARONS = -3,
            CULT_OF_HESH = -2,
            JAKES = 1,
        },
        wealth_support = {
            2,
            1,
            -1,
            -2,
        },
    },
    candidate_cult = {
        cast_id = "candidate_cult",
        character = "BISHOP_OF_FOAM",
        workplace = "PEARL_CULT_COMPOUND",

        platform = "ARTIFACT_TREATMENT",

        stances = {
            ARTIFACT_TREATMENT = 2,
        },
        faction_support = {
            -- rewrite this entire thing
            CULT_OF_HESH = 3,
            SPARK_BARONS = -3,
            FEUD_CITIZEN = 1,
            BOGGERS = 2,
            JAKES = -1,
            BILEBROKERS = -2,
        },
        wealth_support = {
            2,
            -1,
            -2,
            1,
        },
    },
    candidate_jakes = {
        cast_id = "candidate_jakes",
        -- temp character
        character = "ANDWANETTE",
        workplace = "PEARL_PARTY_STORE",

        -- main = "Deregulation",
        -- desc = "Drops many regulation to allow a healthier economy.",
        platform = "SUBSTANCE_REGULATION",

        stances = {
            SUBSTANCE_REGULATION = -2,
        },
        faction_support = {
            ADMIRALTY = -3,
            FEUD_CITIZEN = 1,
            BANDITS = 2,
            -- RISE = ,
            SPARK_BARONS = -1,
            CULT_OF_HESH = -2,
            JAKES = 3,
        },
        wealth_support = {
            2,
            -2,
            1,
            -1,
        },
    },
}
for id, data in pairs(t) do
    if not data.cast_id then
        data.cast_id = id
    end
end
return t