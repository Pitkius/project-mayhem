--[[
  Nuotraukų / avatarų saugykla ant disko (ne MySQL MEDIUMTEXT).
  DB laiko tik metaduomenis + file_key. Tinka 100+ concurrent žaidėjams.
  Naudoja SaveResourceFile / LoadResourceFile (FiveM) — be Lua package.*.
]]

PhotoStorage = PhotoStorage or {}

local RES = GetCurrentResourceName()

local CACHE_MAX = 48
local CACHE_TTL_MS = 90000
local photoCache = {} --- [id] = { data = dataUrl, at = GetGameTimer() }
local cacheOrder = {}

local function cfg()
    return (Config.Phone and Config.Phone.Media) or {}
end

local function mediaRelRoot()
    return tostring(cfg().relativeDir or 'data/media'):gsub('\\', '/'):gsub('^/+', ''):gsub('/+$', '')
end

local function photosRel()
    return mediaRelRoot() .. '/photos'
end

local function avatarsRel()
    return mediaRelRoot() .. '/avatars'
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

--- Reliatyvus kelias resursui (SaveResourceFile / LoadResourceFile)
function PhotoStorage.photoRel(fileKey)
    if not fileKey or fileKey == '' then return nil end
    local safe = tostring(fileKey):gsub('[^%w%._%-]', '')
    if safe == '' then return nil end
    return photosRel() .. '/' .. safe
end

function PhotoStorage.avatarRel(citizenid)
    local safe = tostring(citizenid or ''):gsub('[^%w%-_]', '')
    if safe == '' then return nil end
    return avatarsRel() .. '/' .. safe .. '.b64'
end

--- Absoliutus kelias (tik os.remove)
local function absFromRel(rel)
    if not rel then return nil end
    local root = GetResourcePath(RES)
    if not root or root == '' then return nil end
    return (root:gsub('\\', '/') .. '/' .. rel:gsub('\\', '/'))
end

local function writeTextFile(rel, content)
    if not rel or content == nil then return false end
    content = tostring(content)
    return SaveResourceFile(RES, rel, content, #content) and true or false
end

local function readTextFile(rel)
    if not rel then return nil end
    return LoadResourceFile(RES, rel)
end

local function deleteFile(rel)
    local abs = absFromRel(rel)
    if not abs then return end
    os.remove(abs)
end

local function ensureMarker(relDir)
    local marker = relDir .. '/.keep'
    if LoadResourceFile(RES, marker) then return true end
    return SaveResourceFile(RES, marker, '', 0) and true or false
end

function PhotoStorage.ensureFolders()
    ensureMarker(mediaRelRoot())
    ensureMarker(photosRel())
    ensureMarker(avatarsRel())
end

--- Atgalinis suderinamumas su senesniais keliais
function PhotoStorage.photoPath(fileKey)
    return absFromRel(PhotoStorage.photoRel(fileKey))
end

function PhotoStorage.avatarPath(citizenid)
    return absFromRel(PhotoStorage.avatarRel(citizenid))
end

--- Iš data URL / base64 → failas ant disko. Grąžina file_key (pvz. 123.b64)
function PhotoStorage.writePhoto(photoId, imageData)
    PhotoStorage.ensureFolders()
    photoId = tonumber(photoId)
    if not photoId then return nil end
    local b64 = stripDataUrl(imageData)
    if not b64 or #b64 < 32 then return nil end
    local key = ('%d.b64'):format(photoId)
    local rel = PhotoStorage.photoRel(key)
    if not writeTextFile(rel, b64) then return nil end
    cacheForget(photoId)
    return key
end

function PhotoStorage.readPhotoDataUrl(photoId, fileKey)
    photoId = tonumber(photoId)
    if photoId then
        local cached = cacheGet(photoId)
        if cached then return cached end
    end
    local rel = PhotoStorage.photoRel(fileKey)
    local raw = readTextFile(rel)
    if not raw or #raw < 32 then return '' end
    local url = ('data:image/jpeg;base64,%s'):format(raw:gsub('%s', ''))
    if photoId then cacheSet(photoId, url) end
    return url
end

function PhotoStorage.deletePhotoFile(fileKey)
    deleteFile(PhotoStorage.photoRel(fileKey))
end

function PhotoStorage.writeAvatar(citizenid, imageData)
    PhotoStorage.ensureFolders()
    local b64 = stripDataUrl(imageData)
    if not b64 or #b64 < 32 then return false end
    local rel = PhotoStorage.avatarRel(citizenid)
    return writeTextFile(rel, b64)
end

function PhotoStorage.readAvatarDataUrl(citizenid)
    local raw = readTextFile(PhotoStorage.avatarRel(citizenid))
    if not raw or #raw < 32 then return '' end
    return ('data:image/jpeg;base64,%s'):format(raw:gsub('%s', ''))
end

function PhotoStorage.hasAvatar(citizenid)
    local rel = PhotoStorage.avatarRel(citizenid)
    if not rel then return false end
    local raw = LoadResourceFile(RES, rel)
    return raw ~= nil and #raw > 32
end

function PhotoStorage.deleteAvatar(citizenid)
    deleteFile(PhotoStorage.avatarRel(citizenid))
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
