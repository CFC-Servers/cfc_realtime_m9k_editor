CFCM9kEditor = {
    updateM9kMessage = "CFC_EntityStubber_ModifyM9k",
    saveWeaponMessage = "CFC_EntityStubber_SaveWeapon"
}

local infoPrint = "(%s) Changing [%s.%s] %f -> %f"
function CFCM9kEditor.updateWeaponValues( className, delta, who )
    local storedWeapon = weapons.GetStored( className )

    -- NOTE: Expects that all changes will be done on .Primary
    local err = "Expected '%s' to exist on %s"
    for key, value in pairs( delta.Primary ) do
        local oldValue = storedWeapon.Primary[key]

        if oldValue == nil then
            local msg = string.format( err, key, className )
            error( msg )
        end

        if value ~= oldValue then
            local info = string.format( infoPrint, who, className, key, oldValue, value )
            print( info )

            storedWeapon.Primary[key] = value
        end
    end
end
