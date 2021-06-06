if not SERVER then return end

print("RUNNING SERVERSIDE M9K CODE")

local rawset = rawset
local startsWith = string.StartWith
local round = math.Round

util.AddNetworkString( CFCM9kEditor.updateM9kMessage )
util.AddNetworkString( CFCM9kEditor.saveWeaponMessage )
util.AddNetworkString( "CFC_EntityStubber_ModifyM9k_GetWeaponData" )

-- className: { Primary: <settings delta> }
local savedSettings = {}

-- className: <bool>
local dirtyStatus = {}
local saveFileName = "cfc_m9k_saved_settings.json"

local function saveSettings()
    local data = util.TableToJSON( savedSettings )
    file.Write( "cfc_m9k_saved_settings.json", data )
end

hook.Add( "InitPostEntity", "CFC_EntityStubber_ModifyM9k_RestoreSettings", function()
    local saveData = file.Read( saveFileName )
    local data = util.JSONToTable( saveData )

    for className in pairs( data ) do
        dirtyStatus[className] = false
    end

    savedSettings = data
end )

net.Receive( "CFC_EntityStubber_ModifyM9k_GetWeaponData", function( _, ply )
    local primaries = {}

    for _, weaponData in ipairs( weapons.GetList() ) do
        local className = weaponData.ClassName

        if startsWith( className, "m9k" ) then
            local primaryData = {}

            for property, value in pairs( weaponData.Primary ) do
                if isnumber( value ) then
                    rawset( primaryData, property, value )
                end
            end

            primaryData = { Primary = primaryData }
            rawset( primaries, className, primaryData )
        end
    end

    net.Start( "CFC_EntityStubber_ModifyM9k_GetWeaponData" )
    net.WriteTable( primaries )
    net.Send( ply )
end )

net.Receive( CFCM9kEditor.saveWeaponMessage, function( _, ply )
    if not IsValid( ply ) then return end
    if not ply:IsAdmin() then return end

    local className = net.ReadString()

    dirtyStatus[className] = false

    local weaponData = weapons.GetStored( className ).Primary
    savedSettings[className] = weaponData

    saveSettings()

    net.Start( CFCM9kEditor.saveWeaponMessage )
        net.WriteString( className )
        net.WriteString( ply:Nick() )
    net.Broadcast()
end )

net.Receive( CFCM9kEditor.updateM9kMessage, function( _, ply )
    if not IsValid( ply ) then return end
    if not ply:IsAdmin() then return end

    local className = net.ReadString()
    local delta = net.ReadTable()

    dirtyStatus[className] = true

    local err = "Expected a number, got '%s' for %s.%s"
    for k, v in pairs( delta.Primary ) do
        if isnumber( v ) then
            delta.Primary[k] = round( v, 2 )
        else
            local msg = string.format( err, v, className, k )
            error( msg )
        end
    end

    CFCM9kEditor.updateWeaponValues( className, delta, ply:Nick() )

    net.Start( CFCM9kEditor.updateM9kMessage )
        net.WriteString( className )
        net.WriteTable( delta )
        net.WriteString( ply:Nick() )
    net.Broadcast()
end )
