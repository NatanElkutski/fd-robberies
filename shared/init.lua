--[[
    Namespace shared by every file of this resource on one side (client or server).
    Modules expose their public API as FD.<Module>; everything else stays local.
]]

FD = {
    Resource = GetCurrentResourceName(),
    IsServer = IsDuplicityVersion(),
}
