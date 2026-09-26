--[[
    Location robberies (server): generic "go to the marked spot and do the job" contracts.
]]

FD.Contracts.OnComplete('location', function(src, id, _, contract)
    local amount = FD.Contracts.RollReward(id)
    FD.Rewards.GiveDirtyMoney(src, amount)
    contract.objectiveDone = true
    Bridge.Notify(src, locale('location.completed', amount), 'success')
end)
