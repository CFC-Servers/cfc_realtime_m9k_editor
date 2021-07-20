if not CLIENT then return end

print("RUNNING CLIENT M9K CODE")

defaultWeaponData = {}
weaponsByCategory = {}

-- className: <bool>
local dirtyStatus = {}
local selectedWeapon = nil
local wrenchIcon = "icon16/wrench.png"

net.Receive( CFCM9kEditor.updateM9kMessage, function()
    local className = net.ReadString()
    local delta = net.ReadTable()
    local who = net.ReadString()

    dirtyStatus[className] = true
    CFCM9kEditor.updateWeaponValues( className, delta, who )
end )

net.Receive( CFCM9kEditor.saveWeaponMessage, function()
    local className = net.ReadString()
    local who = net.ReadString()
    dirtyStatus[className] = false

    chat.AddText( "(", who, ")", "Saved: ", className )
end )

local updateFromPanel = function( wepClass, property, value )
    local delta = { Primary = {} }
    delta.Primary[property] = value

    -- I think this is all we need, because the server will send it back to us
    -- and we'll just set it in the weapons table normally
    net.Start( CFCM9kEditor.updateM9kMessage )
        net.WriteString( wepClass )
        net.WriteTable( delta )
    net.SendToServer()
end

local function populatePanel( panel )
    -- Tree
    local tree = vgui.Create( "DTree", panel )
    tree:Dock( TOP )
    tree:SetHeight( 450 )

    -- Create all of the category folders and all weapons therein
    for category, weps in pairs( weaponsByCategory ) do
        local categoryNode = tree:AddNode( category )
        categoryNode.isDir = true

        -- Simply create the node with the right name and attach
        -- the className, so we know what to do with this when we click on it later
        for className, printName in pairs ( weps ) do
            local wepNode = categoryNode:AddNode( printName, wrenchIcon )
            wepNode.wepClass = className
            wepNode.printName = printName
        end
    end

    -- Editor
    tree.OnNodeSelected = function( _, node )
        -- The directories are nodes too, we don't care about clicking on those
        if node.isDir then return end
        local wepClass = node.wepClass
        local dirtyStatusText = dirtyStatus[wepClass] and "DIRTY" or "SAVED"

        local popup = vgui.Create( "DFrame" )
        popup:SetSize( 750, 300 )
        popup:Center()
        popup:MakePopup()
        popup:SetTitle( node.printName .. " - [" .. dirtyStatusText .. "]" )

        local editor = vgui.Create( "DProperties", popup )
        editor:Dock( FILL )

        -- TODO: Hot-reload this if someone else changes it while you view it
        -- (If a change comes through with the same classname as our selectedWeapon)
        selectedWeapon = wepClass
        local wep = weapons.GetStored( wepClass )
        local categories = {
            Primary = wep.Primary,
            --Secondary = wep.Secondary
        }

        -- Loop through those categories ^ (Just Primary for now)
        for categoryName, categoryData in pairs( categories ) do

            -- Loop through all of the data for that category
            for property, value in pairs( categoryData ) do

                -- Only look at numbers
                if isnumber( value ) then
                    local defaultValue = defaultWeaponData[wepClass][property]

                    -- Create the row, estimate the max value, hook up the onChange callback
                    local row = editor:CreateRow( categoryName, property )
                    row:Setup( "Float", { min = 0, max = defaultValue * 40 } )
                    row:SetValue( value )

                    row.queuedValue = nil
                    row.updateTimerName = "m9k_value_update_" .. wepClass .. property
                    row.startUpdateTimer = function()
                        timer.Create( row.updateTimerName, 0.2, 0, function()
                            updateFromPanel( wepClass, property, row.queuedValue )
                            timer.Remove( row.updateTimerName )
                        end )
                    end

                    row.DataChanged = function( _, val )
                        row.queuedValue = val
                        row.startUpdateTimer()
                    end
                end
            end
        end

        local resetButton = vgui.Create( "DButton", popup )
        resetButton:SetText( "Reset" )
        resetButton:Dock( BOTTOM )
        resetButton:SetHeight( 60 )
        resetButton.DoClick = function()
            CFCM9kEditor.updateWeaponValues(
                wepClass,
                { Primary = defaultWeaponData[wepClass] },
                LocalPlayer():Nick()
            )

            dirtyStatus[wepClass] = true

            popup:Close()
            surface.PlaySound( "buttons/button6.wav" )
        end

        local saveButton = vgui.Create( "DButton", popup )
        saveButton:SetText( "Save" )
        saveButton:Dock( BOTTOM )
        saveButton:SetHeight( 60 )
        saveButton.DoClick = function()
            net.Start( CFCM9kEditor.saveWeaponMessage )
                net.WriteString( wepClass )
            net.SendToServer()

            popup:Close()
            surface.PlaySound( "buttons/button5.wav")
        end

    end
end

hook.Add( "AddToolMenuCategories", "CFC_EntityStubber_ModifyM9k", function()
    spawnmenu.AddToolCategory( "Options", "Entity Stubber", "Entity Stubber" )
end )

hook.Add( "PopulateToolMenu", "CFC_EntityStubber_ModifyM9k", function()
    spawnmenu.AddToolMenuOption( "Options", "Entity Stubber", "m9k_editor", "M9k Editor", "", "", function( panel )
        populatePanel( panel )
    end )
end )

-- Generate a list of all weapons with their ClassName, Categories, and PrintName
hook.Add( "InitPostEntity", "CFC_EntityStubber_SetupModifyM9k", function()
    for _, wep in ipairs( weapons.GetList() ) do
        if wep.Category then
            local wepCategory = wep.Category
            local className = wep.ClassName
            local printName = wep.PrintName

            local category = weaponsByCategory[wepCategory]
            weaponsByCategory[wepCategory] = category or {}
            weaponsByCategory[wepCategory][className] = printName

            local primary = wep.Primary
            local watchedValues = {}

            for property, value in pairs( primary ) do
                if isnumber( value ) then
                    watchedValues[property] = value
                end
            end

            defaultWeaponData[className] = watchedValues
        end
    end

    net.Start( "CFC_EntityStubber_ModifyM9k_GetWeaponData" )
    net.SendToServer()
end )

net.Receive( "CFC_EntityStubber_ModifyM9k_GetWeaponData", function()
    local primaryData = net.ReadTable()

    for className, primary in pairs( primaryData ) do
        CFCM9kEditor.updateWeaponValues( className, primary, "server" )
    end
end )
