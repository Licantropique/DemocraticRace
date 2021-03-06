return 
{
    -- This slideshow plays if the player skips the prologue completely!
    
    --sound_event = "event:/vo/narrator/cutscene/sal_intro",
    music = "event:/music/slideshow_sal",
    script=
    {
        {
            mov = 'movies/smith_act1_slide_04.ogv',
            txt = "You are arrested and taken into Admiralty custody. You will go under a criminal investigation.",
        },
        {
            img = 'DEMOCRATICRACE:assets/slides/arrested_1.png',
            txt = "However, due to the crippling bureaucracy present in the Admiralty, the investigation, "..
            "which is supposed to be done within one or two days, has taken at least a week.\n\n" ..
            "During this time, you are detained in a holding cell, with no way out, and certainly no way to run for a campaign.\n\n" ..
            "Your advisor, when you needed them the most, is nowhere to be seen.",
        },
        {
            mov = 'movies/rook_act4_slide_03c.ogv',
            txt = "By the time you got out, it is too late.\n\n" ..
            "The election is already over, and another candidate becomes the ruler of Havaria.\n\n" ..
            "This is where your journey ends.",
        },
       
    }
}    

