local patch_id = "ADD_ANGRIFY_LOC"
if not rawget(_G, patch_id) then
    rawset(_G, patch_id, true)
    print("Loaded patch:"..patch_id)
    loc.angrify = function(str)
        return str:gsub("[" .. LOC"PUNCTUATION.PERIOD" .. "]", LOC"PUNCTUATION.EXCLAMATION")
    end
    Content.AddStringTable("ANGRIFY_LOCS",{
        PUNCTUATION = 
        {
            PERIOD = ".",
            EXCLAMATION = "!",
        },
    })
end