RegisterNetEvent('lrrp_stables:trainerRename',function(horseId,newName)
    local src=source
    if not VORPAdapter.isTrainer(src) then return VORPAdapter.notify(src,Lang.trainerOnly) end
    local identifier,charid=VORPAdapter.identity(src)
    local h=DB.single('SELECT id FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),identifier,charid})
    if not h then return end
    DB.update('UPDATE lrrp_horses SET name=? WHERE id=?',{tostring(newName or 'Cavalo'):sub(1,32),h.id})
end)
