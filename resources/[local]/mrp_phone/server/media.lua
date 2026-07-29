--[[
  Nuotraukų / avatarų saugykla ant disko (ne MySQL MEDIUMTEXT).
  DB laiko tik metaduomenis + file_key. Tinka 100+ concurrent žaidėjams.
]]

PhotoStorage = PhotoStorage or {}

local RES = GetCurrentResourceName()
local resPath = GetResourcePath(RES)

local CACHE_MAX = 48
local CACHE_TTL_MS = 90000
local photoCache = {} --- [id] = { data = dataUrl, at = GetGameTimer() }
local cacheOrder = {}

local function cfg()
    return (Config.Phone and Config.Phone.Media) or {}
end

local function mediaRoot()
    local sub = tostring(cfg().relativeDir or 'data/media')
    return ('%s/%s'):format(resPath:gsub('\\', '/'), sub:gsub('\\', '/'))
end

local function photosDir()
    return mediaRoot() .. '/photos'
end

local function avatarsDir()
    return mediaRoot() .. '/avatars'
end

local function ensureDir(absPath)
    absPath = absPath:gsub('\\', '/')
    local sep = package.config:sub(1, 1)
    if sep == '\\' then
        os.execute(('if not exist "%s" mkdir "%s"'):format(absPath:gsub('/', '\\'), absPath:gsub('/', '\\')))
    else
        os.execute(('mkdir -p %q'):format(absPath))
    end
end

local function cacheGet(id)
    local e = photoCache[id]
    if not e then return nil end
    if (GetGameTimer() - (e.at or 0)) > CACHE_TTL_MS then
        photoCache[id] = nil
        return nil
    end
    return e.data
end

local function cacheSet(id, data)
    if not id or not data then return end
    if not photoCache[id] then
        cacheOrder[#cacheOrder + 1] = id
        while #cacheOrder > CACHE_MAX do
            local old = table.remove(cacheOrder, 1)
            photoCache[old] = nil
        end
    end
    photoCache[id] = { data = data, at = GetGameTimer() }
end

local function cacheForget(id)
    photoCache[id] = nil
end

local function stripDataUrl(imageData)
    imageData = tostring(imageData or ''):match('^%s*(.-)%s*$') or ''
    local b64 = imageData:match('base64,(.+)$')
    if b64 then return b64 end
    return imageData
end

function PhotoStorage.ensureFolders()
    ensureDir(mediaRoot())
    ensureDir(photosDir())
    ensureDir(avatarsDir())
end

function PhotoStorage.photoPath(fileKey)
    if not fileKey or fileKey == '' then return nil end
    local safe = tostring(fileKey):gsub('[^%w%._%-]', '')
    if safe == '' then return nil end
    return photosDir() .. '/' .. safe
end

function PhotoStorage.avatarPath(citizenid)
    local safe = tostring(citizenid or ''):gsub('[^%w%-_]', '')
    if safe == '' then return nil end
    return avatarsDir() .. '/' .. safe .. '.b64'
end

local function writeTextFile(path, content)
    if not path then return false end
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function readTextFile(path)
    if not path then return nil end
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read('*a')
    f:close()
    return data
end

local function deleteFile(path)
    if not path then return end
    os.remove(path)
end

--- Iš data URL / base64 → failas ant disko. Grąžina file_key (pvz. 123.b64)
function PhotoStorage.writePhoto(photoId, imageData)
    PhotoStorage.ensureFolders()
    photoId = tonumber(photoId)
    if not photoId then return nil end
    local b64 = stripDataUrl(imageData)
    if not b64 or #b64 < 32 then return nil end
    local key = ('%d.b64'):format(photoId)
    local path = PhotoStorage.photoPath(key)
    if not writeTextFile(path, b64) then return nil end
    cacheForget(photoId)
    return key
end

function PhotoStorage.readPhotoDataUrl(photoId, fileKey)
    photoId = tonumber(photoId)
    if photoId then
        local cached = cacheGet(photoId)
        if cached then return cached end
    end
    local path = PhotoStorage.photoPath(fileKey)
    local raw = readTextFile(path)
    if not raw or #raw < 32 then return '' end
    local url = ('data:image/jpeg;base64,%s'):format(raw:gsub('%s', ''))
    if photoId then cacheSet(photoId, url) end
    return url
end

function PhotoStorage.deletePhotoFile(fileKey)
    deleteFile(PhotoStorage.photoPath(fileKey))
end

function PhotoStorage.writeAvatar(citizenid, imageData)
    PhotoStorage.ensureFolders()
    local b64 = stripDataUrl(imageData)
    if not b64 or #b64 < 32 then return false end
    local path = PhotoStorage.avatarPath(citizenid)
    return writeTextFile(path, b64)
end

function PhotoStorage.readAvatarDataUrl(citizenid)
    local raw = readTextFile(PhotoStorage.avatarPath(citizenid))
    if not raw or #raw < 32 then return '' end
    return ('data:image/jpeg;base64,%s'):format(raw:gsub('%s', ''))
end

function PhotoStorage.hasAvatar(citizenid)
    local path = PhotoStorage.avatarPath(citizenid)
    if not path then return false end
    local f = io.open(path, 'rb')
    if not f then return false end
    f:close()
    return true
end

function PhotoStorage.deleteAvatar(citizenid)
    deleteFile(PhotoStorage.avatarPath(citizenid))
end

--- Vienkartinė / paleidimo migracija: image_data → diskas
function PhotoStorage.migrateFromDatabase(batchSize)
    batchSize = tonumber(batchSize) or 25
    local rows = MySQL.query.await([[
        SELECT id, image_data, file_key
        FROM fivempro_phone_photos
        WHERE (file_key IS NULL OR file_key = '')
          AND image_data IS NOT NULL
          AND CHAR_LENGTH(image_data) > 64
        ORDER BY id ASC
        LIMIT ?
    ]], { batchSize }) or {}
    local migrated = 0
    for _, row in ipairs(rows) do
        local key = PhotoStorage.writePhoto(row.id, row.image_data)
        if key then
            MySQL.update.await(
                'UPDATE fivempro_phone_photos SET file_key = ?, image_data = NULL WHERE id = ?',
                { key, row.id }
            )
            migrated = migrated + 1
        end
    end
    return migrated, #rows
end

function PhotoStorage.migrateAvatars(batchSize)
    batchSize = tonumber(batchSize) or 25
    local rows = MySQL.query.await([[
        SELECT citizenid, avatar_data
        FROM fivempro_phone_ad_profiles
        WHERE avatar_data IS NOT NULL
          AND CHAR_LENGTH(avatar_data) > 64
        ORDER BY id ASC
        LIMIT ?
    ]], { batchSize }) or {}
    local migrated = 0
    for _, row in ipairs(rows) do
        if PhotoStorage.writeAvatar(row.citizenid, row.avatar_data) then
            MySQL.update.await(
                'UPDATE fivempro_phone_ad_profiles SET avatar_data = NULL WHERE citizenid = ?',
                { row.citizenid }
            )
            migrated = migrated + 1
        end
    end
    return migrated, #rows
end

AddEventHandler('onResourceStart', function(res)
    if res ~= RES then return end
    PhotoStorage.ensureFolders()
end)
