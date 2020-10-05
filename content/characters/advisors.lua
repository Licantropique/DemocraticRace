local chars = 
{
    CharacterDef("ADVISOR_DIPLOMACY",
	{
        base_def = "SPARK_BARON_TASKMASTER",
        bio = "Aellon is not sure what the word \"based\" means as an adjective, but it sounds hip and cool to him, and that's good enough for him to use it everywhere.",
        name = "Aellon",
        nickname = "*The Based",
        tags = {"advisor", "advisor_diplomacy"},
        gender = "MALE",
        species = "HUMAN",

        build = "male_clust_trademaster",
        head = "head_male_shopkeep_002",

        hair_colour = 0xB55239FF,
        skin_colour = 0xF0B8A0FF,

        renown = 4,

        -- social_boons = table.empty,
    }),
    CharacterDef("ADVISOR_MANIPULATE",
	{
        base_def = "PRIEST_PROMOTED",
        -- bio = "Your first mistake is listening to Benni. Your second mistake is believing in her.",
        bio = "After a freak lumin accident, Benni grew two extra fingers on each hand and the ability to speak really fact. I mean, <i>really</>, really fast.",
        name = "Benni",
        title = "Priest",

        tags = {"advisor", "advisor_manipulate"},
        gender = "FEMALE",
        species = "KRADESHI",

        build = "female_tei_utaro_build",
        head = "head_female_kradeshi_13",

        skin_colour = 0xBEC867FF,

        renown = 4,

        -- social_boons = table.empty,
    }),
    CharacterDef("ADVISOR_HOSTILE",
	{
        base_def = "JAKES_SMUGGLER",
        bio = "Dronumph is very impatient, and prefers solving his problems with fists (or guns, more accurately). It's a good thing that he's legally not allowed to do that first in Democratic Havaria.",
        name = "Dronumph",

        tags = {"advisor", "advisor_hostile"},
        gender = "MALE",
        species = "JARACKLE",

        build = "male_phicket",
        head = "head_male_jarackle_bandit_02",

        skin_colour = 0xB8A792FF,

        renown = 4,

        -- social_boons = table.empty,
    }),
}
for _, def in pairs(chars) do
    def.alias = def.id
    def.unique = true
    Content.AddCharacterDef( def )
    -- character_def:InheritBaseDef()
    Content.GetCharacterDef(def.id):InheritBaseDef()
end
