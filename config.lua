-- config.lua (unchanged + DL formats)
-- config.lua (shared)
Config = {}

Config.Cards = {
    driver = {
        label = "Driver's License",
        fakeable = true,
        jobRequired = nil -- anyone
    },
    badge = {
        label = "Police Badge",
        fakeable = true,
        jobRequired = {'police', 'sheriff', 'lspd', 'bcso'} -- adjust for your server
    },
    marijuana = {
        label = "Medical Marijuana Card",
        fakeable = true,
        jobRequired = nil -- anyone (add item check later if needed)
    }
    -- Extensible: Add more like:
    -- ccw = {
    --     label = "Concealed Carry Permit",
    --     fakeable = true,
    --     jobRequired = nil
    -- }
}

Config.DLFormats = {
    number = function() 
        return string.char(math.random(65,90)) .. string.format("%07d", math.random(1000000,9999999)) 
    end,
    exp = function() 
        local exp = os.time() + math.random(3,8)*365*86400
        return os.date('%m/%y', exp) 
    end,
    issue = function() 
        return os.date('%m/%d/%Y') 
    end
}