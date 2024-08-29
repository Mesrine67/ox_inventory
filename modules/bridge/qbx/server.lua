assert(lib.checkDependency('qbx_core', '1.18.0'), 'qbx_core v1.18.0 or higher is required')
assert(lib.checkDependency('qbx_vehicles', '1.2.0'), 'qbx_vehicles v1.2.0 or higher is required')
local Inventory = require 'modules.inventory.server'
local QBX = exports.qbx_core

AddEventHandler('qbx_core:server:playerLoggedOut', server.playerDropped)

AddEventHandler('qbx_core:server:onGroupUpdate', function(source, groupName, groupGrade)
    local inventory = Inventory(source)
    if not inventory then return end
    inventory.player.groups[groupName] = not groupGrade and nil or groupGrade
end)

local function setupPlayer(playerData)
    playerData.identifier = playerData.citizenid
    playerData.name = ('%s %s'):format(playerData.charinfo.firstname, playerData.charinfo.lastname)
    server.setPlayerInventory(playerData)

    local accounts = Inventory.GetAccountItemCounts(playerData.source)
    if not accounts then return end
    for account in pairs(accounts) do
        local playerAccount = account == 'money' and 'cash' or account
        Inventory.SetItem(playerData.source, account, playerData.money[playerAccount])
    end
end

AddStateBagChangeHandler('loadInventory', nil, function(bagName, _, value)
    if not value then return end
    local plySrc = GetPlayerFromStateBagName(bagName)
    if not plySrc then return end
    setupPlayer(QBX:GetPlayer(plySrc).PlayerData)
end)

SetTimeout(500, function()
    local playersData = QBX:GetPlayersData()
    for i = 1, #playersData do setupPlayer(playersData[i]) end
end)

function server.UseItem(source, itemName, data)
    local cb = QBX:CanUseItem(itemName)
    return cb and cb(source, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    local groups = QBX:GetGroups(player.source)
    return {
        source = player.source,
        name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        groups = groups,
        sex = player.charinfo.gender,
        dateofbirth = player.charinfo.birthdate,
    }
end

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    local accounts = Inventory.GetAccountItemCounts(inv)

    if not accounts then return end
    local player = QBX:GetPlayer(inv.id)

    for account, amount in pairs(accounts) do
        account = account == 'money' and 'cash' or account
        if player.Functions.GetMoney(account) ~= amount then
            player.Functions.SetMoney(account, amount, ('Sync %s with inventory'):format(account))
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = QBX:GetPlayer(inv.id)
    return player and player.PlayerData.metadata.licences[license]
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = QBX:GetPlayer(inv.id)
    if not player then return end

    if player.PlayerData.metadata.licences[license.name] then
        return false, 'already_have'
    elseif Inventory.GetItem(inv, 'money', false, true) < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)
    player.PlayerData.metadata.licences[license.name] = true
    player.Functions.SetMetaData('licences', player.PlayerData.metadata.licences)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    return QBX:IsGradeBoss(group, grade)
end

--- Retrieves the job data of a player.
---@param playerId number The ID of the player whose job data is to be retrieved.
---@return table The job data including name, label, grade, and isboss status.
function server.getplayerDataJob(playerId)
    local player = QBX:GetPlayer(playerId)
    if player and player.PlayerData and player.PlayerData.job then
        local dataJob = player.PlayerData.job
        return {
            name = dataJob.name,
            label = dataJob.label,
            grade = {
                level = dataJob.grade.level,
                name = dataJob.grade.name
            },
            isboss = dataJob.isboss
        }
    end
end

--- Gets the player's bank balance.
---@param playerId number The ID of the player.
---@return number The bank balance of the player.
function server.getPlayerBankBalance(playerId)
    local player = QBX:GetPlayer(playerId)
    return player.PlayerData.money.bank
end

--- Removes money from a player's bank account.
---@param playerId number The ID of the player.
---@param amount number The amount of money to remove.
---@return boolean Indicates if the money was successfully removed.
function server.removePlayerBankMoney(playerId, amount)
    local player = QBX:GetPlayer(playerId)
    return player.Functions.RemoveMoney('bank', amount, 'ox-shop')
end

--- Retrieves the balance of the player's society account.
---@param playerId number The ID of the player.
---@return number The balance of the player's society account.
function server.getPlayerSocietyBalance(playerId)
    local player = QBX:GetPlayer(playerId)
    local jobName = player.PlayerData.job.name
    local accountRB = exports['Renewed-Banking']:getAccountMoney(jobName) or 0
    return accountRB
end

--- Removes money from a player's society account.
---@param playerId number The ID of the player.
---@param amount number The amount of money to remove.
---@return boolean Indicates if the money was successfully removed.
function server.removePlayerSocietyMoney(playerId, amount)
    local player = QBX:GetPlayer(playerId)
    local playerName = player.PlayerData.name
    local jobName = player.PlayerData.job.name
	local withdrawSuccess = exports['Renewed-Banking']:removeAccountMoney(jobName, amount)
	if withdrawSuccess then
		exports['Renewed-Banking']:handleTransaction(jobName, 'Retrait du compte professionnel', -amount, 'Achat effectué du compte professionnel via un commerce', 'Système de travail', playerName, 'withdraw')
    else
        return false
    end
    return true
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return Entity(entityId).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(entityId)) or GetVehicleNumberPlateText(entityId)
end
