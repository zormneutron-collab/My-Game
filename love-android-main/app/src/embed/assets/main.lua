love.graphics.setDefaultFilter("nearest", "nearest")

local gameState = "logo"
local score, lives, highScore = 0, 5, 0
local isNight = false
local cycleTimer, difficulty, gameTime, cherryCount = 0, 1, 0, 0
local objects, imgs, snds = {}, {}, {}
local floatingTexts = {}
local font_big, font_small
local font_info, font_title, font_medium, font_large
local font_tiny, font_small2, font_small3, font_new
local shakeTimer, spawnTimer = 0, 0
local lastDifficultyLevel = 1

local PLAYER_SPEED = 820
local TABLE_Y = 0  -- يُحسب في love.load بعد تحميل الصور

-- ===== متغير وميض زر Skin =====
local skinBtnFlash = false   -- هل يومض زر skin؟
local skinBtnFlashTimer = 0  -- مؤقت الوميض

-- ===== متغيرات اللوجو =====
local logoAlpha    = 0
local logoTimer    = 0
local logoState    = "fadein"
local LOGO_FADEIN  = 1.2
local LOGO_HOLD    = 1.5
local LOGO_FADEOUT = 1.2

-- ===== متغيرات scroll لنافذة Info =====
local infoScrollY       = 0
local infoMaxScroll     = 0
local infoDragStartY    = nil
local infoDragScrollStart = nil

-- ===== متغير زر Back في صفحة Info =====
local _infoBtnBack = nil

-- ===== متغيرات شاشة الموت =====
local deathTimer       = 0
local deathCountdown   = 10
local _deathAdBtn, _deathExitBtn = nil, nil
local adWaitingForResult = false
local adUsedThisRound    = false
local adNotAvailable     = false

-- ===== مسارات التواصل مع Java =====
local AD_CMD_PATH    = "/data/data/com.pixel.juice/files/ad_command.txt"
local AD_RESULT_PATH = "/data/data/com.pixel.juice/files/ad_result.txt"

-- ===== نظام الأكواب =====
local currentCup = "water"  -- الكوب الحالي المستخدم
local unlockedCups = {}     -- الأكواب المفتوحة
local selectedCup = "water" -- الكوب المختار في قائمة Skin

-- تعريف جميع الأكواب
local cupDefs = {
    -- أكواب عادية (تُفتح بالسكور)
    { id = "water",      img = "image/water_cup.png",      name = "Water Cup",      unlockScore = 0,    adUnlock = false },
    { id = "orange",     img = "image/orange_cup.png",     name = "Orange Cup",     unlockScore = 1000, adUnlock = false },
    { id = "berrie",     img = "image/Berrie_cup.png",     name = "Berry Cup",      unlockScore = 1000, adUnlock = false },
    { id = "watermelon", img = "image/watermelon_cup.png", name = "Watermelon Cup", unlockScore = 3000, adUnlock = false },
    { id = "cherry",     img = "image/cherry_cup.png",     name = "Cherry Cup",     unlockScore = 4000, adUnlock = false },
    { id = "dolphin",    img = "image/Dolphin_cup_vip.png",name = "Dolphin Cup",    unlockScore = 6000, adUnlock = false },
    -- أكواب إعلانات (بدون gold/diamond/cat - هذه للتحديات فقط)
    { id = "cocktail",   img = "image/cocktail_cup.png",   name = "Cocktail Cup",   unlockScore = 0,    adUnlock = true },
    { id = "wine",       img = "image/wine_cup.png",       name = "Wine Cup",       unlockScore = 0,    adUnlock = true },
    { id = "rose",       img = "image/rose_cup_vip.png",   name = "Rose Cup",       unlockScore = 0,    adUnlock = true },
    -- أكواب التحديات الحصرية (challengeUnlock = true)
    { id = "gold",       img = "image/gold_cup_vip.png",   name = "Gold Cup",       unlockScore = 0,    adUnlock = false, challengeUnlock = true, challengeSet = 1 },
    { id = "diamond",    img = "image/diamond_cup_vip.png",name = "Diamond Cup",    unlockScore = 0,    adUnlock = false, challengeUnlock = true, challengeSet = 2 },
    { id = "cat",        img = "image/cat_cup_vip.png",    name = "Cat Cup",        unlockScore = 0,    adUnlock = false, challengeUnlock = true, challengeSet = 3 },
}

-- ===== مميزات كل كوب =====
-- iceScore: نقاط الثلج | coffeePenalty: عقوبة القهوة | effectDuration: مدة المهارات | shieldDuration: مدة الدرع
local cupStats = {
    water      = { iceScore = 5,  coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    orange     = { iceScore = 7,  coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    berrie     = { iceScore = 7,  coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    watermelon = { iceScore = 10, coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    dolphin    = { iceScore = 15, coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    cherry     = { iceScore = 20, coffeePenalty = 20, effectDuration = 10, shieldDuration = 30 },
    -- أكواب الإعلانات: درع 40 ثانية
    cocktail   = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
    wine       = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
    diamond    = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
    gold       = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
    rose       = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
    cat        = { iceScore = 20, coffeePenalty = 15, effectDuration = 15, shieldDuration = 40 },
}

-- دالة مساعدة للحصول على إحصائيات الكوب الحالي
local function getCupStats()
    return cupStats[selectedCup] or cupStats.water
end

local cupImages = {}  -- صور الأكواب المحملة

-- ===== نظام التحديات =====
local CHALLENGES_PATH = "/data/data/com.pixel.juice/files/challenges.txt"

-- تعريف المجموعات الثلاث من التحديات
local challengeSets = {
    -- المجموعة 1: جائزتها Gold Cup
    {
        reward = "gold",
        rewardName = "Gold Cup",
        title = "SET 1 - Gold Cup",
        challenges = {
            { id = "c1_1", desc = "Reach 5000 pts in one round",   type = "score",    target = 5000,  progress = 0, done = false },
            { id = "c1_2", desc = "Catch 50 ice cubes in one round",type = "ice",     target = 50,    progress = 0, done = false },
            { id = "c1_3", desc = "Collect 4 cherries in one round",type = "cherry4", target = 1,     progress = 0, done = false },
            { id = "c1_4", desc = "Play 3 minutes without dying",   type = "survive", target = 180,   progress = 0, done = false },
            { id = "c1_5", desc = "Avoid coffee 10 times in a row", type = "nocoffee",target = 10,    progress = 0, done = false },
            { id = "c1_6", desc = "Dodge 5 rocks in one round",     type = "rockdodge",target = 5,    progress = 0, done = false },
            { id = "c1_7", desc = "Score 100 pts during night",     type = "night",   target = 100,   progress = 0, done = false },
        }
    },
    -- المجموعة 2: جائزتها Diamond Cup
    {
        reward = "diamond",
        rewardName = "Diamond Cup",
        title = "SET 2 - Diamond Cup",
        challenges = {
            { id = "c2_1", desc = "Reach 10000 pts in one round",  type = "score",    target = 10000, progress = 0, done = false },
            { id = "c2_2", desc = "Catch 100 ice cubes in one round",type = "ice",    target = 100,   progress = 0, done = false },
            { id = "c2_3", desc = "Use blueberry shield 5 times",  type = "blueberry",target = 5,     progress = 0, done = false },
            { id = "c2_4", desc = "Play 5 minutes without dying",  type = "survive",  target = 300,   progress = 0, done = false },
            { id = "c2_5", desc = "Collect 8 cherries in one round",type = "cherry8", target = 1,     progress = 0, done = false },
            { id = "c2_6", desc = "Dodge 15 rocks in one round",   type = "rockdodge",target = 15,    progress = 0, done = false },
            { id = "c2_7", desc = "Score 500 pts during night",    type = "night",    target = 500,   progress = 0, done = false },
        }
    },
    -- المجموعة 3: جائزتها Cat Cup
    {
        reward = "cat",
        rewardName = "Cat Cup",
        title = "SET 3 - Cat Cup",
        challenges = {
            { id = "c3_1", desc = "Reach 20000 pts in one round",  type = "score",    target = 20000, progress = 0, done = false },
            { id = "c3_2", desc = "Catch 200 ice cubes in one round",type = "ice",    target = 200,   progress = 0, done = false },
            { id = "c3_3", desc = "Use watermelon shield 3 times", type = "shield",   target = 3,     progress = 0, done = false },
            { id = "c3_4", desc = "Play 10 minutes without dying", type = "survive",  target = 600,   progress = 0, done = false },
            { id = "c3_5", desc = "Get x2 score 10 times",         type = "cranberry",target = 10,    progress = 0, done = false },
            { id = "c3_6", desc = "Dodge 30 rocks in one round",   type = "rockdodge",target = 30,    progress = 0, done = false },
            { id = "c3_7", desc = "Score 2000 pts during night",   type = "night",    target = 2000,  progress = 0, done = false },
        }
    },
}

-- متغيرات تتبع التحديات أثناء اللعب
local challengeTrack = {
    iceThisRound    = 0,
    coffeeAvoided   = 0,  -- متتالية
    rockDodged      = 0,
    nightScore      = 0,
    cherryThisRound = 0,
    surviveTime     = 0,
    blueberryUsed   = 0,
    shieldUsed      = 0,
    cranberryUsed   = 0,
}

local gameState_challenges = "list"  -- "list" | "detail"
local challengeSelectedSet = 1

-- ===== متغيرات نافذة Skin =====
local skinScrollY = 0
local skinMaxScroll = 0
local skinDragStartY = nil
local skinDragScrollStart = nil
local _skinAdUnlockCup = nil   -- الكوب الذي ننتظر فتحه بإعلان
local adForSkin = false        -- هل الإعلان لفتح skin؟
local _skinBtnBack = nil

-- ===== متغيرات الإعدادات =====
local settings = {
    soundOn  = true,   -- مؤثرات الصوت
    musicOn  = true,   -- الموسيقى
    controlMode = "follow",
}
local _settingsBtnBack    = nil
local _settingsSoundBtn   = nil
local _settingsMusicBtn   = nil
local _settingsControlBtn = nil
local previousGameState = "menu"  -- للعودة الصحيحة من الإعدادات
local _challengesBtnBack = nil

-- ===== متغيرات الموسيقى =====
local currentMusicState = ""   -- "home" | "play" | "over"
local currentPlayTrack  = 1    -- 1 أو 2

local function stopAllMusic()
    snds.musicHome:stop()
    snds.musicPlay1:stop()
    snds.musicPlay2:stop()
    snds.musicOver:stop()
end

local function playMusic(state)
    if currentMusicState == state then return end
    stopAllMusic()
    currentMusicState = state
    if state == "home" then
        snds.musicHome:play()
    elseif state == "play" then
        currentPlayTrack = 1
        snds.musicPlay1:play()
    elseif state == "over" then
        snds.musicOver:play()
    end
end

-- ===== متغير وميض الكوب الجديد =====
local newCupFlash = nil  -- { cupId, timer }

-- ===== متغيرات تأثيرات العناصر =====
local activeEffects = {
    noCoffee    = 0,     -- إيقاف أضرار القهوة (توت أزرق)
    speed       = 0,     -- سرعة إضافية (برتقال)
    doubleScore = 0,     -- مضاعفة النقاط (توت بري)
    rockShield  = 0,     -- درع من الصخور (بطيخة) - عداد زمني
}

-- ===== متغير تتبع الإصبع =====
local touchX = nil
local touchActive = false

local function writeAdCommand(cmd)
    local f = io.open(AD_CMD_PATH, "w")
    if f then f:write(cmd); f:close() end
end

local function readAdResult()
    local f = io.open(AD_RESULT_PATH, "r")
    if not f then return nil end
    local result = f:read("*l")
    f:close()
    os.remove(AD_RESULT_PATH)
    return result
end

local function callShowAd()
    if love.system.getOS() ~= "Android" then return end
    writeAdCommand("show")
    adWaitingForResult = true
    adNotAvailable     = false
end

local function pollAdReward()
    if not adWaitingForResult then return false end
    local result = readAdResult()
    if result == "reward" then
        adWaitingForResult = false
        adNotAvailable     = false
        return true
    elseif result == "skipped" or result == "failed" then
        adWaitingForResult = false
        adNotAvailable     = true
        return false
    end
    return false
end

-- ===== حفظ وتحميل البيانات =====
local HS_PATH      = "/data/data/com.pixel.juice/files/highscore.txt"
local CUPS_PATH    = "/data/data/com.pixel.juice/files/cups.txt"
local SETTINGS_PATH= "/data/data/com.pixel.juice/files/settings.txt"
local CHAL_PATH    = "/data/data/com.pixel.juice/files/challenges.txt"

local function saveChallenges()
    local f = io.open(CHAL_PATH, "w")
    if not f then return end
    for si, s in ipairs(challengeSets) do
        for _, c in ipairs(s.challenges) do
            f:write(c.id .. "=" .. tostring(c.progress) .. "," .. (c.done and "1" or "0") .. "\n")
        end
    end
    f:close()
end

local function loadChallenges()
    local f = io.open(CHAL_PATH, "r")
    if not f then return end
    local data = {}
    for line in f:lines() do
        local id, rest = line:match("^(.-)=(.+)$")
        if id and rest then
            local prog, done = rest:match("^(%d+),(%d)$")
            data[id] = { progress = tonumber(prog) or 0, done = done == "1" }
        end
    end
    f:close()
    for _, s in ipairs(challengeSets) do
        for _, c in ipairs(s.challenges) do
            if data[c.id] then
                c.progress = data[c.id].progress
                c.done     = data[c.id].done
            end
        end
    end
end

local function isSetComplete(setIdx)
    for _, c in ipairs(challengeSets[setIdx].challenges) do
        if not c.done then return false end
    end
    return true
end

function loadHighScore()
    local f = io.open(HS_PATH, "r")
    if f then highScore = tonumber(f:read("*l")) or 0; f:close() end
end

function saveScore()
    if score > highScore then
        highScore = score
        local f = io.open(HS_PATH, "w")
        if f then f:write(tostring(highScore)); f:close() end
    end
end

local function loadCups()
    unlockedCups = { water = true }  -- كوب الماء مفتوح دائماً
    selectedCup  = "water"
    local f = io.open(CUPS_PATH, "r")
    if f then
        for line in f:lines() do
            local key, val = line:match("^(.-)=(.+)$")
            if key == "selected" then
                selectedCup = val
            elseif key and val == "1" then
                unlockedCups[key] = true
            end
        end
        f:close()
    end
end

local function saveCups()
    local f = io.open(CUPS_PATH, "w")
    if f then
        f:write("selected=" .. selectedCup .. "\n")
        for k, v in pairs(unlockedCups) do
            if v then f:write(k .. "=1\n") end
        end
        f:close()
    end
end

local function loadSettings()
    local f = io.open(SETTINGS_PATH, "r")
    if f then
        for line in f:lines() do
            local key, val = line:match("^(.-)=(.+)$")
            if key == "sound"   then settings.soundOn    = (val == "1") end
            if key == "music"   then settings.musicOn    = (val == "1") end
            if key == "control" then settings.controlMode = val end
        end
        f:close()
    end
end

local function saveSettings()
    local f = io.open(SETTINGS_PATH, "w")
    if f then
        f:write("sound="   .. (settings.soundOn and "1" or "0") .. "\n")
        f:write("music="   .. (settings.musicOn  and "1" or "0") .. "\n")
        f:write("control=" .. settings.controlMode .. "\n")
        f:close()
    end
end

local function applySound()
    -- مؤثرات الصوت: تؤثر على كل الأصوات القصيرة
    local sfxVol = settings.soundOn and 1 or 0
    snds.ice:setVolume(sfxVol);      snds.coffee:setVolume(sfxVol)
    snds.cherry:setVolume(sfxVol);   snds.loseLife:setVolume(sfxVol)
    snds.levelUp:setVolume(sfxVol);  snds.warning:setVolume(sfxVol)
    snds.click:setVolume(sfxVol);    snds.night:setVolume(sfxVol)
    snds.day:setVolume(sfxVol);      snds.shield:setVolume(sfxVol)
    -- الموسيقى منفصلة
    local musicVol = settings.musicOn and 1 or 0
    snds.musicHome:setVolume(musicVol)
    snds.musicPlay1:setVolume(musicVol)
    snds.musicPlay2:setVolume(musicVol)
    snds.musicOver:setVolume(musicVol)
end

-- ===== فتح الأكواب تلقائياً حسب السكور =====
local function checkCupUnlocks()
    local milestones = {
        { score = 1000,  cups = {"orange", "berrie"} },
        { score = 3000,  cups = {"watermelon"} },
        { score = 4000,  cups = {"cherry"} },
        { score = 6000,  cups = {"dolphin"} },
    }
    -- ملاحظة: نستخدم highScore للفتح الدائم
    for _, m in ipairs(milestones) do
        if highScore >= m.score then
            for _, cid in ipairs(m.cups) do
                if not unlockedCups[cid] then
                    unlockedCups[cid] = true
                    saveCups()
                    newCupFlash = { cupId = cid, timer = 3.0 }
                    skinBtnFlash = true
                    skinBtnFlashTimer = 60.0  -- يومض زر skin لمدة 5 ثواني
                end
            end
        end
    end
    -- cherry_cup هو id الكوب كرز
end

-- ===== تشغيل شاشة الموت =====
local function triggerDeath()
    saveScore()
    checkCupUnlocks()
    objects        = {}
    floatingTexts  = {}
    deathTimer     = 0
    deathCountdown = 10
    adWaitingForResult = false
    adNotAvailable     = false
    _deathAdBtn, _deathExitBtn = nil, nil
    -- أكواب الإعلانات تنتهي عند الموت
    for _, cd in ipairs(cupDefs) do
        if cd.adUnlock then unlockedCups[cd.id] = false end
    end
    local selectedIsAd = false
    for _, cd in ipairs(cupDefs) do
        if cd.id == selectedCup and cd.adUnlock then selectedIsAd = true end
    end
    if selectedIsAd then selectedCup = "water"; saveCups() end
    gameState = "death"
    playMusic("over")
end

function love.load()
    font_big    = love.graphics.newFont(38)
    font_small  = love.graphics.newFont(18)
    font_info   = love.graphics.newFont(14)
    font_title  = love.graphics.newFont(26)
    font_medium = love.graphics.newFont(22)
    font_large  = love.graphics.newFont(24)
    font_tiny   = love.graphics.newFont(11)
    font_small2 = love.graphics.newFont(13)
    font_small3 = love.graphics.newFont(15)
    font_new    = love.graphics.newFont(20)

    -- صورة اللاعب الأساسية (تُستبدل بالكوب المختار لاحقاً)
    imgs.player    = love.graphics.newImage("image/water_cup.png")
    imgs.bgDay     = love.graphics.newImage("image/background.png")
    imgs.bgNight   = love.graphics.newImage("image/night_background.png")
    imgs.life      = love.graphics.newImage("image/life.png")
    imgs.btnPlay   = love.graphics.newImage("image/button_play.png")
    imgs.btnInfo   = love.graphics.newImage("image/button_info.png")
    imgs.btnPause  = love.graphics.newImage("image/pause.png")
    imgs.ice       = love.graphics.newImage("image/ice.png")
    imgs.cherry    = love.graphics.newImage("image/cherry.png")
    imgs.coffee    = love.graphics.newImage("image/coffee.png")
    imgs.coffee2   = love.graphics.newImage("image/coffee2.png")
    imgs.uiPanel   = love.graphics.newImage("image/ui.png")
    imgs.btnContinue = love.graphics.newImage("image/button_ continue.png")
    imgs.btnRestart  = love.graphics.newImage("image/button_return.png")
    imgs.btnHome     = love.graphics.newImage("image/button_back.png")
    imgs.logo        = love.graphics.newImage("image/logo.png")
    imgs.table_img   = love.graphics.newImage("image/table.png")
    imgs.frame       = love.graphics.newImage("image/frame.png")
    imgs.adFrame        = love.graphics.newImage("image/ad_frame.png")
    imgs.challengeFrame = love.graphics.newImage("image/challenge_frame.png")
    imgs.btnSkin     = love.graphics.newImage("image/skin_button.png")
    imgs.btnSettings = love.graphics.newImage("image/settings_button.png")
    imgs.btnTarget   = love.graphics.newImage("image/target_button.png")

    -- العناصر الجديدة
    imgs.blueberry   = love.graphics.newImage("image/blueberry.png")
    imgs.orange      = love.graphics.newImage("image/orange.png")
    imgs.cranberry   = love.graphics.newImage("image/cranberry.png")
    imgs.watermelon  = love.graphics.newImage("image/watermelon.png")
    imgs.stones      = love.graphics.newImage("image/stones.png")

    -- تحميل صور الأكواب
    for _, cd in ipairs(cupDefs) do
        local ok, img = pcall(love.graphics.newImage, cd.img)
        if ok then cupImages[cd.id] = img end
    end

    snds.ice      = love.audio.newSource("Sound/pick_ice.wav",    "static")
    snds.coffee   = love.audio.newSource("Sound/pick_coffe.wav",  "static")
    snds.cherry   = love.audio.newSource("Sound/Pick_cherry.wav", "static")
    snds.loseLife = love.audio.newSource("Sound/lost_life.wav",   "static")
    snds.levelUp  = love.audio.newSource("Sound/level_up.wav",    "static")
    snds.warning  = love.audio.newSource("Sound/low_life.wav",    "static")
    snds.click    = love.audio.newSource("Sound/click.wav",       "static")
    snds.night    = love.audio.newSource("Sound/night.wav",       "static")
    snds.day      = love.audio.newSource("Sound/start_day.wav",   "static")
    snds.shield   = love.audio.newSource("Sound/shield.wav",      "static")
    -- موسيقى الخلفية
    snds.musicHome  = love.audio.newSource("Sound/home.ogg",        "stream")
    snds.musicPlay1 = love.audio.newSource("Sound/game_play_1.ogg", "stream")
    snds.musicPlay2 = love.audio.newSource("Sound/game_play_2.ogg", "stream")
    snds.musicOver  = love.audio.newSource("Sound/gameover.ogg",    "stream")
    snds.musicHome:setLooping(true)
    snds.musicPlay1:setLooping(false)
    snds.musicPlay2:setLooping(false)
    snds.musicOver:setLooping(false)

    SW, SH = love.graphics.getDimensions()

    -- حساب موضع الطاولة الثابتة (في أسفل الشاشة تماماً)
    local tw = imgs.table_img:getWidth()
    local th = imgs.table_img:getHeight()
    local tableScale = SW / tw
    local tableH = th * tableScale
    TABLE_Y = SH - tableH  -- الطاولة في أسفل الشاشة تماماً

    player = {
        x = SW/2,
        y = TABLE_Y + 115,   -- الكوب يجلس فوق الطاولة مباشرة
        w = 80, h = 80,
        speed = 850
    }

    loadHighScore()
    loadCups()
    loadSettings()
    loadChallenges()
    checkCupUnlocks()
    applySound()
    updatePlayerCup()
end

-- ===== تحديث صورة الكوب =====
function updatePlayerCup()
    local img = cupImages[selectedCup]
    if img then
        imgs.player = img
        player.w = img:getWidth()
        player.h = img:getHeight()
    end
end

-- ===== تحديث شاشة اللوجو =====
local function updateLogo(dt)
    logoTimer = logoTimer + dt
    if logoState == "fadein" then
        logoAlpha = math.min(1, logoTimer / LOGO_FADEIN)
        if logoTimer >= LOGO_FADEIN then logoTimer = 0; logoState = "hold" end
    elseif logoState == "hold" then
        logoAlpha = 1
        if logoTimer >= LOGO_HOLD then logoTimer = 0; logoState = "fadeout" end
    elseif logoState == "fadeout" then
        logoAlpha = math.max(0, 1 - logoTimer / LOGO_FADEOUT)
        if logoTimer >= LOGO_FADEOUT then gameState = "menu"; playMusic("home") end
    end
end

local function drawLogo()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, SW, SH)
    local lw = imgs.logo:getWidth()
    local lh = imgs.logo:getHeight()
    local scale = math.min(SW * 0.7 / lw, SH * 0.4 / lh)
    love.graphics.setColor(1, 1, 1, logoAlpha)
    love.graphics.draw(imgs.logo, SW/2, SH/2, 0, scale, scale, lw/2, lh/2)
end

function updateGame(dt)
    gameTime   = gameTime + dt
    challengeTrack.surviveTime = challengeTrack.surviveTime + dt
    difficulty = 1 + (gameTime / 60) * 0.20
    if math.floor(difficulty * 10) > math.floor(lastDifficultyLevel * 10) then
        snds.levelUp:play(); lastDifficultyLevel = difficulty
    end

    if shakeTimer > 0 then shakeTimer = shakeTimer - dt end

    local oldNight = isNight
    cycleTimer = cycleTimer + dt
    if cycleTimer > 20 then isNight = not isNight; cycleTimer = 0 end
    if oldNight ~= isNight then
        if isNight then snds.night:play() else snds.day:play() end
    end

    -- تحديث تأثيرات العناصر
    if activeEffects.noCoffee > 0    then activeEffects.noCoffee    = activeEffects.noCoffee    - dt end
    if activeEffects.speed > 0       then activeEffects.speed        = activeEffects.speed        - dt end
    if activeEffects.doubleScore > 0 then activeEffects.doubleScore  = activeEffects.doubleScore  - dt end
    if activeEffects.rockShield > 0  then activeEffects.rockShield   = activeEffects.rockShield   - dt end

    -- حركة اللاعب
    local currentSpeed = PLAYER_SPEED
    if activeEffects.speed > 0 then currentSpeed = currentSpeed * 1.6 end

    if settings.controlMode == "follow" then
        -- وضع تتبع الإصبع - انسيابي مع تأثير السرعة
        if touchActive and touchX then
            local diff = touchX - player.x
            -- السرعة الأساسية للانسيابية، ومضاعفة عند تأثير البرتقال
            local followSpeed = activeEffects.speed > 0 and 18 or 10
            player.x = player.x + diff * followSpeed * dt
        end
    else
        -- وضع يمين/يسار
        if love.mouse.isDown(1) then
            local mx = love.mouse.getX()
            if mx < SW/2 then
                player.x = player.x - currentSpeed * dt
            else
                player.x = player.x + currentSpeed * dt
            end
        end
    end
    player.x = math.max(player.w/2, math.min(SW - player.w/2, player.x))

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnObject()
        local spawnRate = math.max(0.18, math.random(0.4, 1.1) / (1 + (gameTime / 60) * 0.2))
        spawnTimer = spawnRate
    end

    for i = #objects, 1, -1 do
        local o = objects[i]
        if not o.isFading then
            o.y = o.y + o.vy * dt
            o.x = o.x + o.vx * dt

            if o.x - o.w/2 < 0 then
                o.x  = o.w/2; o.vx = math.abs(o.vx)
            elseif o.x + o.w/2 > SW then
                o.x  = SW - o.w/2; o.vx = -math.abs(o.vx)
            end

            local hitWidth = player.w + 10
            if (o.x > player.x - hitWidth/2) and (o.x < player.x + hitWidth/2) and
               (o.y + o.h/2 > player.y) and (o.y < player.y + 40) then
                o.isFading = true; processScore(o)
                if gameState == "death" then return end  -- الصخرة قتلت اللاعب
            end
        else
            o.x       = o.x + (player.x - o.x) * 15 * dt
            o.y       = o.y + (player.y + 40 - o.y) * 15 * dt
            o.opacity = o.opacity - dt * 8
            if o.opacity <= 0 then table.remove(objects, i) end
        end

        if o.y > SH then
            if not o.isFading then
                if o.type == "ice" and not isNight then
                    lives = lives - 1; shakeTimer = 0.2; snds.loseLife:play()
                    if lives == 1 then snds.warning:play() end
                    if lives <= 0 then triggerDeath(); return end
                elseif o.type == "stone" then
                    -- الحجر يختفي بدون عقوبة إذا لم يُصطد = الاعب تفاداه
                    challengeTrack.rockDodged = challengeTrack.rockDodged + 1
                end
            end
            table.remove(objects, i)
        end
    end

    for i = #floatingTexts, 1, -1 do
        local t = floatingTexts[i]
        t.y = t.y - 60 * dt; t.timer = t.timer - dt
        if t.timer <= 0 then table.remove(floatingTexts, i) end
    end
end

-- ===== تحديث شاشة الموت =====
local function updateDeath(dt)
    if pollAdReward() then
        -- حياة ثانية فقط (فتح الكوب يُعالَج في love.update)
        if not adForSkin then
            objects = {}; floatingTexts = {}; spawnTimer = 1.0
            lives = 1; adUsedThisRound = true
            playMusic("play")
            gameState = "play"; return
        end
    end

    deathTimer     = deathTimer + dt
    deathCountdown = math.ceil(10 - deathTimer)
    if deathCountdown <= 0 then gameState = "menu"; playMusic("home") end
end

-- ===== رسم شاشة الموت =====
local function drawDeathScreen()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, SW, SH)

    local panelW = SW * 0.82
    local panelH = SH * 0.65
    local panelX = (SW - panelW) / 2
    local panelY = (SH - panelH) / 2

    love.graphics.setColor(0.10, 0.06, 0.22, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 22, 22)
    love.graphics.setColor(0.65, 0.25, 1.0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 22, 22)

    love.graphics.setFont(font_big)
    love.graphics.setColor(1, 0.28, 0.28, 1)
    love.graphics.printf("GAME OVER", panelX, panelY + 26, panelW, "center")

    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SCORE: " .. score,     panelX, panelY + 84,  panelW, "center")
    love.graphics.printf("BEST:  " .. highScore, panelX, panelY + 110, panelW, "center")

    love.graphics.setColor(0.65, 0.25, 1.0, 0.45)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(panelX + 30, panelY + 144, panelX + panelW - 30, panelY + 144)

    local cc = deathCountdown <= 3 and {1, 0.22, 0.22} or {1, 0.85, 0.15}
    love.graphics.setFont(font_big)
    love.graphics.setColor(cc[1], cc[2], cc[3], 1)
    love.graphics.printf(tostring(math.max(deathCountdown, 0)), panelX, panelY + 154, panelW, "center")

    love.graphics.setFont(font_small)
    if adWaitingForResult then
        love.graphics.setColor(0.3, 1, 0.5, 1)
        love.graphics.printf("Watching ad... please wait", panelX, panelY + 204, panelW, "center")
    elseif adNotAvailable then
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.printf("Ad not available, try later", panelX, panelY + 204, panelW, "center")
    else
        love.graphics.setColor(0.75, 0.75, 0.75, 1)
        love.graphics.printf("seconds remaining", panelX, panelY + 204, panelW, "center")
    end

    local adBtnW = panelW - 60
    local adBtnH = 64
    local adBtnX = panelX + 30
    local adBtnY = panelY + 246

    if adUsedThisRound then
        love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.printf("No more chances this round", adBtnX, adBtnY + 22, adBtnW, "center")
        _deathAdBtn = nil
    elseif adNotAvailable then
        love.graphics.setColor(0.35, 0.18, 0.05, 1)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1.0, 0.55, 0.1, 0.75)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1, 0.85, 0.5, 1)
        love.graphics.printf("Ad not ready, Tap to retry", adBtnX, adBtnY + 22, adBtnW, "center")
        _deathAdBtn = { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }
    else
        love.graphics.setColor(adWaitingForResult and 0.3 or 0.12,
                               adWaitingForResult and 0.3 or 0.68,
                               adWaitingForResult and 0.3 or 0.32, 1)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.18, 1.0, 0.48, 0.75)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            adWaitingForResult and "Waiting for reward..." or "Watch Ad & Get 1 Life",
            adBtnX, adBtnY + 22, adBtnW, "center")
        _deathAdBtn = adWaitingForResult and nil
                      or { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }
    end

    local exBtnW = panelW - 60
    local exBtnH = 54
    local exBtnX = panelX + 30
    local exBtnY = adBtnY + adBtnH + 16

    love.graphics.setColor(0.32, 0.10, 0.10, 1)
    love.graphics.rectangle("fill", exBtnX, exBtnY, exBtnW, exBtnH, 14, 14)
    love.graphics.setColor(0.9, 0.18, 0.18, 0.75)
    love.graphics.rectangle("line", exBtnX, exBtnY, exBtnW, exBtnH, 14, 14)
    love.graphics.setColor(1, 0.82, 0.82, 1)
    love.graphics.printf("Exit to Menu", exBtnX, exBtnY + 17, exBtnW, "center")
    _deathExitBtn = { x = exBtnX, y = exBtnY, w = exBtnW, h = exBtnH }
end

-- ===== تحديث تقدم التحديات =====
local function updateChallengeProgress()
    local changed = false
    for si, s in ipairs(challengeSets) do
        for _, c in ipairs(s.challenges) do
            if not c.done then
                local prev = c.progress
                if c.type == "score"     then c.progress = math.max(c.progress, score)
                elseif c.type == "ice"   then c.progress = challengeTrack.iceThisRound
                elseif c.type == "cherry4" then
                    if challengeTrack.cherryThisRound >= 4 then c.progress = 1 end
                elseif c.type == "cherry8" then
                    if challengeTrack.cherryThisRound >= 8 then c.progress = 1 end
                elseif c.type == "survive"   then c.progress = math.floor(challengeTrack.surviveTime)
                elseif c.type == "nocoffee"  then c.progress = math.max(c.progress, challengeTrack.coffeeAvoided)
                elseif c.type == "rockdodge" then c.progress = challengeTrack.rockDodged
                elseif c.type == "night"     then c.progress = math.max(c.progress, challengeTrack.nightScore)
                elseif c.type == "blueberry" then c.progress = math.max(c.progress, challengeTrack.blueberryUsed)
                elseif c.type == "shield"    then c.progress = math.max(c.progress, challengeTrack.shieldUsed)
                elseif c.type == "cranberry" then c.progress = math.max(c.progress, challengeTrack.cranberryUsed)
                end
                if c.progress >= c.target then c.done = true; c.progress = c.target; changed = true end
            end
        end
        -- فتح الكوب إذا اكتملت المجموعة
        if isSetComplete(si) and not unlockedCups[s.reward] then
            unlockedCups[s.reward] = true
            saveCups()
            newCupFlash = { cupId = s.reward, timer = 4.0 }
            skinBtnFlash = true; skinBtnFlashTimer = 8.0
            changed = true
        end
    end
    if changed then saveChallenges() end
end

function processScore(o)
    local col = {1, 1, 1}
    local pts = 0
    local stats = getCupStats()

    if o.type == "coffee" then
        if activeEffects.noCoffee > 0 then
            -- التوت الأزرق يحول القهوة إلى +1
            score = score + 1; col = {0.4, 0.8, 0.4}; pts = 1
        else
            local penalty = stats.coffeePenalty
            score = math.max(0, score - penalty); col = {1, 0.2, 0.2}; pts = -penalty
        end
        snds.coffee:stop(); snds.coffee:play()

    elseif o.type == "cherry" then
        score = score + 25; cherryCount = cherryCount + 1; col = {0.2, 1, 0.2}; pts = 25
        challengeTrack.cherryThisRound = challengeTrack.cherryThisRound + 1
        snds.cherry:stop(); snds.cherry:play()
        if cherryCount >= 4 then lives = math.min(lives + 1, 5); cherryCount = 0 end

    elseif o.type == "stone" then
        if activeEffects.rockShield > 0 then
            activeEffects.rockShield = 0
            challengeTrack.shieldUsed = challengeTrack.shieldUsed + 1
            col = {1, 0.8, 0}
            snds.shield:stop(); snds.shield:play()
            table.insert(floatingTexts, {text = "SHIELD!", x = player.x - 30, y = player.y - 50, timer = 1.5, color = {1,0.8,0}})
        else
            lives = 0; shakeTimer = 0.5; snds.loseLife:play()
            col = {1, 0.2, 0.2}; pts = 0
            table.insert(floatingTexts, {text = "DEAD!", x = player.x - 30, y = player.y - 50, timer = 1.5, color = {1,0.2,0.2}})
            triggerDeath(); return
        end

    elseif o.type == "blueberry" then
        score = score + 30; col = {0.4, 0.4, 1}; pts = 30
        activeEffects.noCoffee = stats.effectDuration
        challengeTrack.blueberryUsed = challengeTrack.blueberryUsed + 1
        table.insert(floatingTexts, {text = "NO COFFEE " .. stats.effectDuration .. "s!", x = player.x - 60, y = player.y - 50, timer = 1.5, color = {0.4,0.6,1}})
        snds.cherry:stop(); snds.cherry:play()

    elseif o.type == "orange" then
        score = score + 30; col = {1, 0.6, 0}; pts = 30
        activeEffects.speed = stats.effectDuration
        table.insert(floatingTexts, {text = "SPEED! " .. stats.effectDuration .. "s!", x = player.x - 50, y = player.y - 50, timer = 1.5, color = {1,0.7,0}})
        snds.cherry:stop(); snds.cherry:play()

    elseif o.type == "cranberry" then
        score = score + 25; col = {0.8, 0.2, 0.8}; pts = 25
        activeEffects.doubleScore = stats.effectDuration
        challengeTrack.cranberryUsed = challengeTrack.cranberryUsed + 1
        table.insert(floatingTexts, {text = "x2 SCORE " .. stats.effectDuration .. "s!", x = player.x - 60, y = player.y - 50, timer = 1.5, color = {0.8,0.3,1}})
        snds.cherry:stop(); snds.cherry:play()

    elseif o.type == "watermelon_fruit" then
        score = score + 50; col = {0.2, 0.9, 0.3}; pts = 50
        activeEffects.rockShield = stats.shieldDuration
        local shieldMsg = "SHIELD! " .. stats.shieldDuration .. "s"
        table.insert(floatingTexts, {text = shieldMsg, x = player.x - 40, y = player.y - 50, timer = 1.5, color = {0.2,0.9,0.3}})
        snds.cherry:stop(); snds.cherry:play()

    else  -- ice
        local baseIce = stats.iceScore
        local pts_ice = activeEffects.doubleScore > 0 and (baseIce * 2) or baseIce
        score = score + pts_ice; col = {0.4, 0.8, 1}; pts = pts_ice
        challengeTrack.iceThisRound = challengeTrack.iceThisRound + 1
        if isNight then challengeTrack.nightScore = challengeTrack.nightScore + pts_ice end
        snds.ice:stop(); snds.ice:play()
    end

    -- تحديث تقدم التحديات
    updateChallengeProgress()

    if pts ~= 0 then
        table.insert(floatingTexts, {
            text = (pts > 0 and "+" or "") .. pts,
            x = player.x - 20, y = player.y - 30, timer = 1.2, color = col
        })
    end
end

function love.draw()
    if gameState == "logo" then drawLogo(); return end

    if gameState == "play" and shakeTimer > 0 then
        love.graphics.translate(math.random(-6, 6), math.random(-6, 6))
    end

    local bg = isNight and imgs.bgNight or imgs.bgDay
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, SW / bg:getWidth(), SH / bg:getHeight())

    if gameState == "play" or gameState == "pause" then
        -- رسم الطاولة
        drawTable()

        -- رسم تأثيرات نشطة
        drawActiveEffects()

        for _, o in ipairs(objects) do
            local sc = o.scale or 1
            -- تأثير الثلج: وميض وردي عند تأثير التوت البري (x2)
            if o.type == "ice" and activeEffects.doubleScore > 0 then
                local flash = (math.sin(love.timer.getTime() * 10) + 1) / 2
                love.graphics.setColor(1, 0.3 + flash * 0.5, 0.8, o.opacity)
            else
                love.graphics.setColor(1, 1, 1, o.opacity)
            end
            -- عند تأثير التوت الأزرق: استبدال صورة القهوة بـ coffee2
            local drawImg = o.img
            if o.type == "coffee" and activeEffects.noCoffee > 0 then
                drawImg = imgs.coffee2
            end
            love.graphics.draw(drawImg, o.x, o.y, o.angle, sc, sc, drawImg:getWidth()/2, drawImg:getHeight()/2)
        end

        -- وميض أخضر عند تأثير البطيخة: أخضر ثم طبيعي بدون شفافية
        if activeEffects.rockShield > 0 then
            local pulse = (math.sin(love.timer.getTime() * 5) + 1) / 2  -- 0..1
            love.graphics.setColor(0.3 + pulse * 0.7, 1, 0.3 + pulse * 0.7, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.draw(imgs.player, player.x, player.y, 0, 1, 1, player.w/2, 0)
        love.graphics.setColor(1, 1, 1, 1)

        for _, t in ipairs(floatingTexts) do
            love.graphics.setFont(font_small)
            love.graphics.setColor(0, 0, 0, t.timer); love.graphics.print(t.text, t.x+2, t.y+2)
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], t.timer)
            love.graphics.print(t.text, t.x, t.y)
        end
        drawUI()
        if gameState == "pause" then drawPauseMenu() end

    elseif gameState == "death" then
        love.graphics.setColor(1, 1, 1, 1)
        drawTable()
        love.graphics.draw(imgs.player, player.x, player.y, 0, 1, 1, player.w/2, 0)
        drawDeathScreen()

    elseif gameState == "menu" then drawMenu()
    elseif gameState == "info"  then drawInfo()
    elseif gameState == "skin"  then drawSkinMenu()
    elseif gameState == "settings"   then drawSettings()
    elseif gameState == "challenges" then drawChallenges()
    end
end

-- ===== رسم الطاولة =====
function drawTable()
    local tw = imgs.table_img:getWidth()
    local tableScale = SW / tw
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.table_img, 0, TABLE_Y, 0, tableScale, tableScale)
end

-- ===== رسم مؤشرات التأثيرات النشطة =====
function drawActiveEffects()
    -- تبدأ من تحت زر الإيقاف (زر الإيقاف عند SW-80,20 بحجم 60)
    local fx = SW - 190
    local fy = 90   -- تحت زر الإيقاف مباشرة
    local fh = 22
    love.graphics.setFont(font_small2)
    if activeEffects.noCoffee > 0 then
        love.graphics.setColor(0.4, 0.6, 1, 1)
        love.graphics.printf("BLOCK " .. math.ceil(activeEffects.noCoffee) .. "s", fx, fy, 180, "right")
        fy = fy + fh
    end
    if activeEffects.speed > 0 then
        love.graphics.setColor(1, 0.7, 0, 1)
        love.graphics.printf("SPEED " .. math.ceil(activeEffects.speed) .. "s", fx, fy, 180, "right")
        fy = fy + fh
    end
    if activeEffects.doubleScore > 0 then
        love.graphics.setColor(0.8, 0.3, 1, 1)
        love.graphics.printf("x2 SCORE " .. math.ceil(activeEffects.doubleScore) .. "s", fx, fy, 180, "right")
        fy = fy + fh
    end
    if activeEffects.rockShield > 0 then
        love.graphics.setColor(0.2, 0.9, 0.3, 1)
        love.graphics.printf("SHIELD " .. math.ceil(activeEffects.rockShield) .. "s", fx, fy, 180, "right")
    end
end

function drawUI()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 15, 15, 200, 150, 12, 12)
    for i = 1, 5 do
        local a = (i <= lives) and 1 or 0.25
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(imgs.life, 25 + (i-1)*35, 30, 0, 1.3, 1.3)
    end
    love.graphics.setColor(1, 1, 1, 1); love.graphics.setFont(font_small)
    love.graphics.print("SCORE: " .. score,                30, 65)
    love.graphics.print("BEST: "  .. highScore,            30, 90)
    love.graphics.print("CHERRY: " .. cherryCount .. "/4", 30, 115)
    love.graphics.draw(imgs.btnPause, SW - 80, 20, 0,
        60 / imgs.btnPause:getWidth(), 60 / imgs.btnPause:getHeight())
end

function drawPauseMenu()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, SW, SH)
    love.graphics.setColor(1, 1, 1, 1)
    local uiScale, btnScale = 4, 2.5
    local uiX, uiY = SW/2, SH/2
    local uiH = imgs.uiPanel:getHeight() * uiScale
    love.graphics.draw(imgs.uiPanel, uiX, uiY, 0, uiScale, uiScale,
        imgs.uiPanel:getWidth()/2, imgs.uiPanel:getHeight()/2)
    local spacing = 80
    local btnY = uiY + (uiH * 0.25)
    love.graphics.draw(imgs.btnHome,     uiX-spacing, btnY, 0, btnScale, btnScale,
        imgs.btnHome:getWidth()/2,     imgs.btnHome:getHeight()/2)
    love.graphics.draw(imgs.btnRestart,  uiX,         btnY, 0, btnScale, btnScale,
        imgs.btnRestart:getWidth()/2,  imgs.btnRestart:getHeight()/2)
    love.graphics.draw(imgs.btnContinue, uiX+spacing, btnY, 0, btnScale, btnScale,
        imgs.btnContinue:getWidth()/2, imgs.btnContinue:getHeight()/2)

    -- زر الإعدادات داخل قائمة الإيقاف
    local sBtnW = 160
    local sBtnH = 44
    local sBtnX = (SW - sBtnW) / 2
    local sBtnY = btnY + 80
    love.graphics.setColor(0.15, 0.15, 0.35, 1)
    love.graphics.rectangle("fill", sBtnX, sBtnY, sBtnW, sBtnH, 10, 10)
    love.graphics.setColor(0.5, 0.5, 1, 0.8)
    love.graphics.rectangle("line", sBtnX, sBtnY, sBtnW, sBtnH, 10, 10)
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Settings", sBtnX, sBtnY + 12, sBtnW, "center")
end

-- ===== رسم قائمة الإعدادات =====
function drawSettings()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, SW, SH)

    local panelW = SW * 0.85
    local panelH = SH * 0.68
    local panelX = (SW - panelW) / 2
    local panelY = (SH - panelH) / 2

    love.graphics.setColor(0.08, 0.10, 0.22, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 18, 18)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 18, 18)

    -- عنوان
    love.graphics.setFont(font_large)
    love.graphics.setColor(0.45, 0.80, 1.0, 1)
    love.graphics.printf("SETTINGS", panelX, panelY + 20, panelW, "center")

    local btnW = panelW * 0.80
    local btnH = 52
    local btnX = panelX + (panelW - btnW) / 2

    -- زر مؤثرات الصوت (SFX)
    local soundY = panelY + 85
    love.graphics.setColor(settings.soundOn and {0.1, 0.45, 0.2} or {0.4, 0.1, 0.1})
    love.graphics.rectangle("fill", btnX, soundY, btnW, btnH, 12, 12)
    love.graphics.setColor(settings.soundOn and {0.2, 1.0, 0.4} or {1.0, 0.3, 0.3})
    love.graphics.rectangle("line", btnX, soundY, btnW, btnH, 12, 12)
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 1)
    -- أيقونة + نص
    love.graphics.printf(settings.soundOn and "SFX: ON" or "SFX: OFF",
        btnX, soundY + 16, btnW, "center")
    _settingsSoundBtn = { x = btnX, y = soundY, w = btnW, h = btnH }

    -- زر الموسيقى
    local musicY = soundY + btnH + 14
    love.graphics.setColor(settings.musicOn and {0.1, 0.25, 0.55} or {0.4, 0.1, 0.1})
    love.graphics.rectangle("fill", btnX, musicY, btnW, btnH, 12, 12)
    love.graphics.setColor(settings.musicOn and {0.3, 0.6, 1.0} or {1.0, 0.3, 0.3})
    love.graphics.rectangle("line", btnX, musicY, btnW, btnH, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(settings.musicOn and "Music: ON" or "Music: OFF",
        btnX, musicY + 16, btnW, "center")
    _settingsMusicBtn = { x = btnX, y = musicY, w = btnW, h = btnH }

    -- زر وضع التحكم
    local ctrlY = musicY + btnH + 14
    love.graphics.setColor(0.1, 0.2, 0.5, 1)
    love.graphics.rectangle("fill", btnX, ctrlY, btnW, btnH, 12, 12)
    love.graphics.setColor(0.3, 0.5, 1.0, 0.8)
    love.graphics.rectangle("line", btnX, ctrlY, btnW, btnH, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    local ctrlLabel = settings.controlMode == "side"
        and "Control: Tap Left/Right"
        or  "Control: Follow Finger"
    love.graphics.printf(ctrlLabel, btnX, ctrlY + 18, btnW, "center")
    _settingsControlBtn = { x = btnX, y = ctrlY, w = btnW, h = btnH }

    -- وصف وضع التحكم
    love.graphics.setFont(font_small2)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local desc = settings.controlMode == "side"
        and "Tap left/right side to move"
        or  "Cup follows your finger"
    love.graphics.printf(desc, btnX, ctrlY + btnH + 8, btnW, "center")

    -- زر الرجوع
    local backY = panelY + panelH + 14
    local backW = panelW * 0.55
    local backX = (SW - backW) / 2
    love.graphics.setColor(0.12, 0.30, 0.60, 1)
    love.graphics.rectangle("fill", backX, backY, backW, 46, 13, 13)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.85)
    love.graphics.rectangle("line", backX, backY, backW, 46, 13, 13)
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", backX, backY + 14, backW, "center")
    _settingsBtnBack = { x = backX, y = backY, w = backW, h = 46 }
end

-- ===== رسم قائمة Skin =====
function drawSkinMenu()
    love.graphics.setColor(0, 0, 0, 0.80)
    love.graphics.rectangle("fill", 0, 0, SW, SH)

    local panelW = SW * 0.92
    local panelH = SH * 0.85
    local panelX = (SW - panelW) / 2
    local panelY = SH * 0.05

    love.graphics.setColor(0.08, 0.10, 0.22, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 18, 18)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 18, 18)

    love.graphics.setFont(font_medium)
    love.graphics.setColor(0.45, 0.80, 1.0, 1)
    love.graphics.printf("CUPS", panelX, panelY + 14, panelW, "center")

    local contentY = panelY + 55
    local cellW = (panelW - 40) / 3
    local cellH = 110
    local pad = 14
    local col = 0

    -- فصل الأكواب
    local normalCups = {}
    local adCups = {}
    local challengeCups = {}
    for _, cd in ipairs(cupDefs) do
        if cd.challengeUnlock then table.insert(challengeCups, cd)
        elseif cd.adUnlock    then table.insert(adCups, cd)
        else                       table.insert(normalCups, cd) end
    end

    love.graphics.setScissor(panelX + 2, panelY + 50, panelW - 4, panelH - 70)

    local drawY = contentY - skinScrollY

    -- عنوان قسم الأكواب العادية
    love.graphics.setFont(font_small3)
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf("-- Normal Cups --", panelX, drawY, panelW, "center")
    drawY = drawY + 28
    col = 0

    for _, cd in ipairs(normalCups) do
        local cx = panelX + pad + col * cellW
        local cy = drawY

        -- الحالة
        local isSelected  = (selectedCup == cd.id)
        local isUnlocked  = unlockedCups[cd.id]
        local isLocked    = not isUnlocked

        -- إطار الكوب
        local fw = imgs.frame:getWidth()
        local fh = imgs.frame:getHeight()
        local fscale = (cellW - 10) / fw

        -- وميض قوس قزح للكوب الجديد
        local isNewCup = newCupFlash and newCupFlash.cupId == cd.id
        if isNewCup then
            local t = love.timer.getTime() * 6
            local r = (math.sin(t)       + 1) / 2
            local g = (math.sin(t + 2.1) + 1) / 2
            local b = (math.sin(t + 4.2) + 1) / 2
            love.graphics.setColor(r, g, b, 1)
        elseif isSelected then
            love.graphics.setColor(1, 0.85, 0, 1)
        elseif isLocked then
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.draw(imgs.frame, cx + 5, cy, 0, fscale, fscale)

        -- رسم إطار وميض إضافي حول الكوب الجديد
        if isNewCup then
            local t = love.timer.getTime() * 6
            local r = (math.sin(t + 1)   + 1) / 2
            local g = (math.sin(t + 3.1) + 1) / 2
            local b = (math.sin(t + 5.2) + 1) / 2
            love.graphics.setColor(r, g, b, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cx + 3, cy - 2, cellW - 6, fh * fscale + 4, 6, 6)
        end

        -- صورة الكوب
        if cupImages[cd.id] then
            local cw = cupImages[cd.id]:getWidth()
            local ch = cupImages[cd.id]:getHeight()
            local cs = math.min((cellW - 30) / cw, (cellH - 40) / ch) * 0.8
            local a = isLocked and 0.35 or 1
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(cupImages[cd.id],
                cx + cellW/2, cy + (fh * fscale) / 2,
                0, cs, cs,
                cw/2, ch/2)
        end

        -- اسم الكوب
        love.graphics.setFont(font_tiny)
        if isSelected then
            love.graphics.setColor(1, 0.85, 0, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(cd.name, cx, cy + fh * fscale + 2, cellW, "center")

        -- قفل أو مختار
        if isLocked then
            love.graphics.setColor(1, 0.4, 0.4, 1)
            local lockTxt = cd.unlockScore > 0 and (cd.unlockScore .. " pts") or "Locked"
            love.graphics.printf(lockTxt, cx, cy + fh * fscale + 18, cellW, "center")
        elseif isSelected then
            love.graphics.setColor(0.2, 1, 0.4, 1)
            love.graphics.printf("[Selected]", cx, cy + fh * fscale + 18, cellW, "center")
        end

        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
    if col > 0 then drawY = drawY + cellH end

    drawY = drawY + 20

    -- عنوان قسم أكواب الإعلانات
    love.graphics.setFont(font_small3)
    love.graphics.setColor(1, 0.6, 0, 1)
    love.graphics.printf("-- Ad Cups (1 Round Only) --", panelX, drawY, panelW, "center")
    drawY = drawY + 28
    col = 0

    for _, cd in ipairs(adCups) do
        local cx = panelX + pad + col * cellW
        local cy = drawY

        local isSelected = (selectedCup == cd.id)
        local isUnlocked = unlockedCups[cd.id]
        local isLocked   = not isUnlocked

        -- إطار الإعلان
        local fw = imgs.adFrame:getWidth()
        local fh = imgs.adFrame:getHeight()
        local fscale = (cellW - 10) / fw
        local isNewCupAd = newCupFlash and newCupFlash.cupId == cd.id
        if isNewCupAd then
            local t = love.timer.getTime() * 6
            local r = (math.sin(t)       + 1) / 2
            local g = (math.sin(t + 2.1) + 1) / 2
            local b = (math.sin(t + 4.2) + 1) / 2
            love.graphics.setColor(r, g, b, 1)
        elseif isSelected then
            love.graphics.setColor(1, 0.85, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.draw(imgs.adFrame, cx + 5, cy, 0, fscale, fscale)
        if isNewCupAd then
            local t = love.timer.getTime() * 6
            local r = (math.sin(t + 1)   + 1) / 2
            local g = (math.sin(t + 3.1) + 1) / 2
            local b = (math.sin(t + 5.2) + 1) / 2
            love.graphics.setColor(r, g, b, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cx + 3, cy - 2, cellW - 6, fh * fscale + 4, 6, 6)
        end

        if cupImages[cd.id] then
            local cw = cupImages[cd.id]:getWidth()
            local ch = cupImages[cd.id]:getHeight()
            local cs = math.min((cellW - 30) / cw, (cellH - 40) / ch) * 0.8
            local a = isLocked and 0.35 or 1
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(cupImages[cd.id],
                cx + cellW/2, cy + (fh * fscale) / 2,
                0, cs, cs, cw/2, ch/2)
        end

        love.graphics.setFont(font_tiny)
        if isSelected then
            love.graphics.setColor(1, 0.85, 0, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(cd.name, cx, cy + fh * fscale + 2, cellW, "center")

        if isLocked then
            love.graphics.setColor(1, 0.7, 0, 1)
            love.graphics.printf("Watch Ad", cx, cy + fh * fscale + 18, cellW, "center")
        elseif isSelected then
            love.graphics.setColor(0.2, 1, 0.4, 1)
            love.graphics.printf("[Selected]", cx, cy + fh * fscale + 18, cellW, "center")
        else
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.printf("Tap to use", cx, cy + fh * fscale + 18, cellW, "center")
        end

        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
    if col > 0 then drawY = drawY + cellH end

    drawY = drawY + 20
    -- قسم أكواب التحديات
    love.graphics.setFont(font_small3)
    love.graphics.setColor(0.9, 0.5, 1, 1)
    love.graphics.printf("-- Challenge Cups --", panelX, drawY, panelW, "center")
    drawY = drawY + 28
    col = 0

    for _, cd in ipairs(challengeCups) do
        local cx2 = panelX + pad + col * cellW
        local cy2 = drawY
        local isSelected = (selectedCup == cd.id)
        local isUnlocked = unlockedCups[cd.id]
        local isLocked   = not isUnlocked

        local fw = imgs.challengeFrame:getWidth()
        local fh2 = imgs.challengeFrame:getHeight()
        local fscale = (cellW - 10) / fw
        if isSelected then love.graphics.setColor(1, 0.85, 0, 1)
        else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(imgs.challengeFrame, cx2 + 5, cy2, 0, fscale, fscale)

        if cupImages[cd.id] then
            local cw = cupImages[cd.id]:getWidth()
            local ch = cupImages[cd.id]:getHeight()
            local cs = math.min((cellW - 30) / cw, (cellH - 40) / ch) * 0.8
            local a = isLocked and 0.25 or 1
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(cupImages[cd.id], cx2 + cellW/2, cy2 + (fh2 * fscale)/2, 0, cs, cs, cw/2, ch/2)
        end

        love.graphics.setFont(font_tiny)
        love.graphics.setColor(isSelected and {1,0.85,0,1} or {0.9,0.9,0.9,1})
        love.graphics.printf(cd.name, cx2, cy2 + fh2 * fscale + 2, cellW, "center")

        if isLocked then
            love.graphics.setColor(0.9, 0.6, 1, 1)
            love.graphics.printf("Challenges", cx2, cy2 + fh2 * fscale + 18, cellW, "center")
        elseif isSelected then
            love.graphics.setColor(0.2, 1, 0.4, 1)
            love.graphics.printf("[Selected]", cx2, cy2 + fh2 * fscale + 18, cellW, "center")
        else
            love.graphics.setColor(0.6, 1, 0.6, 1)
            love.graphics.printf("Tap to use", cx2, cy2 + fh2 * fscale + 18, cellW, "center")
        end

        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
    if col > 0 then drawY = drawY + cellH end

    -- حساب السكرول الأقصى
    local totalContentH = (drawY + skinScrollY) - (contentY) + 20
    skinMaxScroll = math.max(0, totalContentH - (panelH - 70))

    love.graphics.setScissor()

    -- زر الرجوع
    local backW = panelW * 0.55
    local backH = 46
    local backX = (SW - backW) / 2
    local backY = panelY + panelH + 12
    love.graphics.setColor(0.12, 0.30, 0.60, 1)
    love.graphics.rectangle("fill", backX, backY, backW, backH, 13, 13)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.85)
    love.graphics.rectangle("line", backX, backY, backW, backH, 13, 13)
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", backX, backY + 14, backW, "center")
    _skinBtnBack = { x = backX, y = backY, w = backW, h = backH }
end

function drawMenu()
    local btnW = imgs.btnPlay:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.btnPlay, SW/2, SH*0.5,  0, 1, 1, btnW/2, imgs.btnPlay:getHeight()/2)
    love.graphics.draw(imgs.btnInfo, SW/2, SH*0.65, 0, 1, 1, btnW/2, imgs.btnInfo:getHeight()/2)

    -- زر Skin (أسفل يمين)
    local skinSize = 64
    local skinX = SW - skinSize - 20
    local skinY = SH - skinSize - 20

    -- وميض قوس قزح عند فتح كوب جديد
    if skinBtnFlash then
        local t = love.timer.getTime() * 5
        local r = (math.sin(t)       + 1) / 2
        local g = (math.sin(t + 2.1) + 1) / 2
        local b = (math.sin(t + 4.2) + 1) / 2
        -- هالة وميضة حول الزر
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local halo = skinSize * 0.25 * pulse
        love.graphics.setColor(r, g, b, 0.6)
        love.graphics.rectangle("fill",
            skinX - halo, skinY - halo,
            skinSize + halo*2, skinSize + halo*2, 14, 14)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.draw(imgs.btnSkin, skinX, skinY, 0,
        skinSize / imgs.btnSkin:getWidth(),
        skinSize / imgs.btnSkin:getHeight())

    -- اسم زر Skin
    love.graphics.setFont(font_tiny)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Skin", skinX, skinY + skinSize + 2, skinSize, "center")

    -- علامة NEW! فوق الزر عند وجود كوب جديد
    if skinBtnFlash then
        love.graphics.setFont(font_new)
        love.graphics.setColor(1, 0.1, 0.1, 1)
        love.graphics.print("NEW!", skinX - 8, skinY - 26)
    end

    -- زر الإعدادات (أسفل يسار)
    local setSize = 64
    local setX = 20
    local setY = SH - setSize - 20
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.btnSettings, setX, setY, 0,
        setSize / imgs.btnSettings:getWidth(),
        setSize / imgs.btnSettings:getHeight())
    love.graphics.setFont(font_tiny)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Settings", setX, setY + setSize + 2, setSize, "center")

    -- زر التحديات (وسط أسفل)
    local chalSize = 90
    local chalX = SW/2 - chalSize/2
    local chalY = SH - chalSize - 20
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgs.btnTarget, chalX, chalY, 0,
        chalSize / imgs.btnTarget:getWidth(),
        chalSize / imgs.btnTarget:getHeight())
    love.graphics.setFont(font_tiny)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Challenges", chalX, chalY + chalSize + 2, chalSize, "center")

    -- أفضل نتيجة
    love.graphics.setFont(font_big)
    local label  = "BEST SCORE"
    local numStr = tostring(highScore)
    local labelW = font_big:getWidth(label)
    local numW   = font_big:getWidth(numStr)
    local boxW   = math.max(labelW, numW) + 60
    local boxH   = font_big:getHeight() * 2 + 28
    local boxX   = (SW - boxW) / 2
    local boxY   = SH * 0.18

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 14, 14)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(label,  boxX, boxY + 8, boxW, "center")
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf(numStr, boxX, boxY + 8 + font_big:getHeight() + 6, boxW, "center")
end

function drawChallenges()
    -- خلفية
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, SW, SH)

    local panelX = 20; local panelY = 60
    local panelW = SW - 40; local panelH = SH - 130

    love.graphics.setColor(0.1, 0.1, 0.2, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 16, 16)

    -- عنوان
    love.graphics.setFont(font_large)
    love.graphics.setColor(1, 0.85, 0.1, 1)
    love.graphics.printf("CHALLENGES", panelX, panelY + 14, panelW, "center")

    local ty = panelY + 58

    for si, s in ipairs(challengeSets) do
        local complete = isSetComplete(si)
        local rewardUnlocked = unlockedCups[s.reward]

        -- عنوان المجموعة
        love.graphics.setFont(font_small3)
        if rewardUnlocked then
            love.graphics.setColor(1, 0.85, 0, 1)
        elseif complete then
            love.graphics.setColor(0.3, 1, 0.5, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
        end
        love.graphics.printf(s.title .. (rewardUnlocked and "  [DONE]" or ""), panelX + 10, ty, panelW - 20, "left")
        ty = ty + 22

        -- رسم التحديات
        love.graphics.setFont(font_tiny)
        for ci, c in ipairs(s.challenges) do
            -- مربع الحالة
            if c.done then
                love.graphics.setColor(0.2, 0.9, 0.3, 1)
                love.graphics.rectangle("fill", panelX + 14, ty + 2, 12, 12, 3, 3)
                love.graphics.setColor(0.2, 0.9, 0.3, 1)
            else
                love.graphics.setColor(0.4, 0.4, 0.4, 1)
                love.graphics.rectangle("fill", panelX + 14, ty + 2, 12, 12, 3, 3)
                love.graphics.setColor(0.85, 0.85, 0.85, 1)
            end
            -- نص التحدي
            local progTxt = c.done and "DONE" or (c.progress .. "/" .. c.target)
            love.graphics.printf(c.desc, panelX + 32, ty, panelW - 100, "left")
            love.graphics.setColor(c.done and {0.3,1,0.5,1} or {1,0.8,0.3,1})
            love.graphics.printf(progTxt, panelX, ty, panelW - 14, "right")
            ty = ty + 17
        end

        -- جائزة المجموعة
        love.graphics.setFont(font_tiny)
        if rewardUnlocked then
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.printf("Reward: " .. s.rewardName .. " - UNLOCKED!", panelX + 10, ty, panelW - 20, "left")
        else
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.printf("Reward: " .. s.rewardName .. " (complete all 7)", panelX + 10, ty, panelW - 20, "left")
        end
        ty = ty + 22
    end

    -- زر العودة
    local backW = 140; local backH = 44
    local backX = (SW - backW) / 2; local backY = SH - 65
    love.graphics.setColor(0.7, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", backX, backY, backW, backH, 12, 12)
    love.graphics.setFont(font_small2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("BACK", backX, backY + 13, backW, "center")
    _challengesBtnBack = { x = backX, y = backY, w = backW, h = backH }
end

function drawInfo()
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, SW, SH)

    local winW = SW * 0.82
    local winH = SH * 0.68
    local winX = (SW - winW) / 2
    local winY = (SH - winH) / 2 - 30

    love.graphics.setColor(0.08, 0.10, 0.22, 0.97)
    love.graphics.rectangle("fill", winX, winY, winW, winH, 18, 18)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", winX, winY, winW, winH, 18, 18)

    love.graphics.setFont(font_info)
    love.graphics.setScissor(winX + 2, winY + 2, winW - 4, winH - 4)

    local pad = 18
    local tw  = winW - pad * 2
    local tx  = winX + pad
    local lh  = 30
    local sh  = 16
    local ty  = winY + pad - infoScrollY

    local function section(title)
        ty = ty + sh
        love.graphics.setFont(font_info)
        love.graphics.setColor(1, 0.82, 0.2, 1)
        love.graphics.printf(title, tx, ty, tw, "center")
        ty = ty + lh + 2
    end

    local function line(text, r, g, b)
        love.graphics.setFont(font_info)
        love.graphics.setColor(r or 1, g or 1, b or 1, 0.92)
        love.graphics.printf(text, tx, ty, tw, "center")
        ty = ty + lh
    end

    -- سطر مع صورة صغيرة على اليسار
    local function lineImg(img, text, r, g, b)
        local imgSize = 22
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            local sc = imgSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.draw(img, tx, ty + (lh - imgSize)/2, 0, sc, sc)
        end
        love.graphics.setFont(font_info)
        love.graphics.setColor(r or 1, g or 1, b or 1, 0.92)
        love.graphics.printf(text, tx + imgSize + 4, ty, tw - imgSize - 4, "left")
        ty = ty + lh
    end

    local function divider()
        ty = ty + sh
        love.graphics.setColor(1, 1, 1, 0.10)
        love.graphics.rectangle("fill", tx + 10, ty, tw - 20, 1)
        ty = ty + sh
    end

    love.graphics.setFont(font_title)
    love.graphics.setFont(font_title)
    love.graphics.setColor(0.45, 0.80, 1.0, 1)
    love.graphics.printf("HOW TO PLAY", tx, ty, tw, "center")
    ty = ty + 36

    love.graphics.setColor(0.35, 0.55, 1.0, 0.45)
    love.graphics.setLineWidth(1)
    love.graphics.line(tx + 10, ty, tx + tw - 10, ty)
    ty = ty + 10

    love.graphics.setFont(font_info)
    love.graphics.setColor(0.50, 0.50, 0.50, 1)
    love.graphics.printf("Developed by Mamdouh Ibrahim", tx, ty, tw, "center")
    ty = ty + lh

    divider()
    section("CONTROLS")
    line("Tap LEFT  =  move cup left")
    line("Tap RIGHT  =  move cup right")
    line("Or: Follow Finger mode (see Settings)")

    divider()
    section("ITEMS")
    lineImg(imgs.ice,        "ICE CUBE     +pts (depends on cup)",   0.50, 0.90, 1.00)
    lineImg(imgs.coffee,     "COFFEE BEAN  -pts   avoid it",         1.00, 0.40, 0.40)
    lineImg(imgs.cherry,     "CHERRY       +25    4 = 1 life",       0.40, 1.00, 0.50)
    lineImg(imgs.blueberry,  "BLUEBERRY    +30    coffee=+1  10s",   0.5,  0.6,  1.0)
    lineImg(imgs.orange,     "ORANGE       +30    speed up 10s",     1.0,  0.7,  0.0)
    lineImg(imgs.cranberry,  "CRANBERRY    +25    x2 score 10s",     0.8,  0.3,  1.0)
    lineImg(imgs.watermelon, "WATERMELON   +50    shield 30s",       0.2,  0.9,  0.3)
    lineImg(imgs.stones,     "ROCK         INSTANT GAME OVER!",      1.0,  0.2,  0.2)

    divider()
    section("CUPS")
    line("Water Cup:  Start  (+5 ice)")
    line("1000 pts:  Orange Cup (+7)  Berry Cup (+7)")
    line("3000 pts:  Watermelon Cup (+10)")
    line("4000 pts:  Cherry Cup (+20)")
    line("6000 pts:  Dolphin Cup (+15)")
    line("VIP Cups (Ad):  +20 ice, -15 coffee, 15s skills, 40s shield")

    divider()
    section("LIVES")
    line("You start with 5 lives")
    line("Miss an ice cube = lose 1 life")
    line("Rock = INSTANT GAME OVER", 1, 0.3, 0.3)
    line("4 cherries = +1 life", 0.4, 1.0, 0.5)
    line("Watch an ad = second chance")

    divider()
    section("DIFFICULTY")
    line("Speed increases over time")
    line("Night: only coffee falls")
    line("No speed limit, push your limits")

    local contentH = (ty + infoScrollY) - (winY + pad) + 80
    infoMaxScroll = math.max(0, contentH - winH + pad)

    love.graphics.setScissor()

    if infoMaxScroll > 0 then
        local trackH = winH - 20
        local thumbH = math.max(28, trackH * (winH / (winH + infoMaxScroll)))
        local thumbY = winY + 10 + (infoScrollY / infoMaxScroll) * (trackH - thumbH)
        love.graphics.setColor(0.4, 0.6, 1.0, 0.25)
        love.graphics.rectangle("fill", winX + winW - 8, winY + 10, 4, trackH, 2, 2)
        love.graphics.setColor(0.4, 0.6, 1.0, 0.80)
        love.graphics.rectangle("fill", winX + winW - 8, thumbY, 4, thumbH, 2, 2)
    end

    local btnW = winW * 0.55
    local btnH = 46
    local btnX = (SW - btnW) / 2
    local btnY = winY + winH + 14

    love.graphics.setColor(0.12, 0.30, 0.60, 1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 13, 13)
    love.graphics.setColor(0.35, 0.55, 1.0, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 13, 13)
    love.graphics.setFont(font_info)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Back", btnX, btnY + 14, btnW, "center")
    _infoBtnBack = { x = btnX, y = btnY, w = btnW, h = btnH }
end

local function handleDeathClick(x, y)
    if not adUsedThisRound and not adWaitingForResult and _deathAdBtn and
       x >= _deathAdBtn.x and x <= _deathAdBtn.x + _deathAdBtn.w and
       y >= _deathAdBtn.y and y <= _deathAdBtn.y + _deathAdBtn.h then
        snds.click:play()
        adNotAvailable = false
        callShowAd()
        return
    end
    if _deathExitBtn and
       x >= _deathExitBtn.x and x <= _deathExitBtn.x + _deathExitBtn.w and
       y >= _deathExitBtn.y and y <= _deathExitBtn.y + _deathExitBtn.h then
        snds.click:play()
        adWaitingForResult = false; adNotAvailable = false
        gameState = "menu"; return
    end
end

-- ===== نقر قائمة Skin =====
local function handleSkinClick(x, y)
    -- زر الرجوع
    if _skinBtnBack and
       x >= _skinBtnBack.x and x <= _skinBtnBack.x + _skinBtnBack.w and
       y >= _skinBtnBack.y and y <= _skinBtnBack.y + _skinBtnBack.h then
        snds.click:play()
        gameState = "menu"; return
    end

    -- حساب خانات الأكواب
    local panelW = SW * 0.92
    local panelX = (SW - panelW) / 2
    local panelY = SH * 0.05
    local contentY = panelY + 55
    local cellW = (panelW - 40) / 3
    local cellH = 110
    local pad = 14

    local normalCups = {}
    local adCups = {}
    local challengeCups = {}
    for _, cd in ipairs(cupDefs) do
        if cd.challengeUnlock then table.insert(challengeCups, cd)
        elseif cd.adUnlock    then table.insert(adCups, cd)
        else                       table.insert(normalCups, cd) end
    end

    local drawY = contentY - skinScrollY + 28
    local col = 0

    for _, cd in ipairs(normalCups) do
        local cx = panelX + pad + col * cellW
        local cy = drawY
        if x >= cx and x <= cx + cellW and y >= cy and y <= cy + cellH then
            snds.click:play()
            if unlockedCups[cd.id] then
                selectedCup = cd.id; saveCups(); updatePlayerCup()
            end
            return
        end
        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
    if col > 0 then drawY = drawY + cellH end
    drawY = drawY + 20 + 28
    col = 0

    for _, cd in ipairs(adCups) do
        local cx = panelX + pad + col * cellW
        local cy = drawY
        if x >= cx and x <= cx + cellW and y >= cy and y <= cy + cellH then
            snds.click:play()
            if unlockedCups[cd.id] then
                selectedCup = cd.id; saveCups(); updatePlayerCup()
            else
                _skinAdUnlockCup = cd.id
                adForSkin = true
                callShowAd()
            end
            return
        end
        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
    if col > 0 then drawY = drawY + cellH end
    drawY = drawY + 20 + 28
    col = 0

    for _, cd in ipairs(challengeCups) do
        local cx = panelX + pad + col * cellW
        local cy = drawY
        if x >= cx and x <= cx + cellW and y >= cy and y <= cy + cellH then
            snds.click:play()
            if unlockedCups[cd.id] then
                selectedCup = cd.id; saveCups(); updatePlayerCup()
            else
                -- توجيه للتحديات مباشرة
                gameState = "challenges"
            end
            return
        end
        col = col + 1
        if col >= 3 then col = 0; drawY = drawY + cellH end
    end
end

-- ===== نقر الإعدادات =====
local function handleSettingsClick(x, y)
    if _settingsSoundBtn and
       x >= _settingsSoundBtn.x and x <= _settingsSoundBtn.x + _settingsSoundBtn.w and
       y >= _settingsSoundBtn.y and y <= _settingsSoundBtn.y + _settingsSoundBtn.h then
        settings.soundOn = not settings.soundOn
        applySound(); saveSettings()
        snds.click:play(); return
    end
    if _settingsMusicBtn and
       x >= _settingsMusicBtn.x and x <= _settingsMusicBtn.x + _settingsMusicBtn.w and
       y >= _settingsMusicBtn.y and y <= _settingsMusicBtn.y + _settingsMusicBtn.h then
        settings.musicOn = not settings.musicOn
        applySound(); saveSettings()
        snds.click:play(); return
    end
    if _settingsControlBtn and
       x >= _settingsControlBtn.x and x <= _settingsControlBtn.x + _settingsControlBtn.w and
       y >= _settingsControlBtn.y and y <= _settingsControlBtn.y + _settingsControlBtn.h then
        settings.controlMode = (settings.controlMode == "side") and "follow" or "side"
        saveSettings(); snds.click:play(); return
    end
    if _settingsBtnBack and
       x >= _settingsBtnBack.x and x <= _settingsBtnBack.x + _settingsBtnBack.w and
       y >= _settingsBtnBack.y and y <= _settingsBtnBack.y + _settingsBtnBack.h then
        snds.click:play(); gameState = previousGameState; return
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        touchX = x; touchActive = true
        if gameState == "info" then
            infoDragStartY = y; infoDragScrollStart = infoScrollY
        elseif gameState == "skin" then
            skinDragStartY = y; skinDragScrollStart = skinScrollY
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    touchX = x
    if gameState == "info" and infoDragStartY then
        local delta = infoDragStartY - y
        infoScrollY = math.max(0, math.min(infoMaxScroll, infoDragScrollStart + delta))
    elseif gameState == "skin" and skinDragStartY then
        local delta = skinDragStartY - y
        skinScrollY = math.max(0, math.min(skinMaxScroll, skinDragScrollStart + delta))
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    touchActive = false
    infoDragStartY = nil
    skinDragStartY = nil

    if gameState == "death" then
        handleDeathClick(x, y)

    elseif gameState == "menu" then
        local skinSize = 64
        local skinX = SW - skinSize - 20
        local skinY = SH - skinSize - 20
        if x >= skinX and x <= skinX + skinSize and y >= skinY and y <= skinY + skinSize then
            snds.click:play(); skinScrollY = 0
            skinBtnFlash = false; skinBtnFlashTimer = 0  -- أوقف الوميض
            gameState = "skin"; return
        end
        local setSize = 64
        if x >= 20 and x <= 20 + setSize and y >= SH - setSize - 20 and y <= SH - 20 then
            snds.click:play(); previousGameState = "menu"; gameState = "settings"; return
        end
        -- زر التحديات (وسط أسفل)
        local chalSize = 90
        local chalX = SW/2 - chalSize/2
        local chalY = SH - chalSize - 20
        if x >= chalX and x <= chalX + chalSize and y >= chalY and y <= chalY + chalSize then
            snds.click:play(); gameState = "challenges"; return
        end
        if math.abs(x - SW/2) < 100 then
            snds.click:play()
            if     y > SH*0.45 and y < SH*0.55 then resetGame(); gameState = "play"
            elseif y > SH*0.60 and y < SH*0.70 then infoScrollY = 0; gameState = "info" end
        end

    elseif gameState == "info" then
        if _infoBtnBack and
           x >= _infoBtnBack.x and x <= _infoBtnBack.x + _infoBtnBack.w and
           y >= _infoBtnBack.y and y <= _infoBtnBack.y + _infoBtnBack.h then
            snds.click:play(); gameState = "menu"
        end

    elseif gameState == "challenges" then
        if _challengesBtnBack and
           x >= _challengesBtnBack.x and x <= _challengesBtnBack.x + _challengesBtnBack.w and
           y >= _challengesBtnBack.y and y <= _challengesBtnBack.y + _challengesBtnBack.h then
            snds.click:play(); gameState = "menu"
        end

    elseif gameState == "skin" then
        handleSkinClick(x, y)

    elseif gameState == "settings" then
        handleSettingsClick(x, y)

    elseif gameState == "play" then
        if x > SW - 90 and y < 90 then snds.click:play(); gameState = "pause" end

    elseif gameState == "pause" then
        local uiY  = SH/2
        local btnY = uiY + (imgs.uiPanel:getHeight() * 8 * 0.15)
        -- زر الإعدادات في قائمة الإيقاف
        local sBtnW = 160; local sBtnH = 44
        local sBtnX = (SW - sBtnW) / 2; local sBtnY = btnY + 80
        if x >= sBtnX and x <= sBtnX + sBtnW and y >= sBtnY and y <= sBtnY + sBtnH then
            snds.click:play(); previousGameState = "pause"; gameState = "settings"; return
        end
        if math.abs(y - btnY) < 60 then
            snds.click:play()
            if     math.abs(x - (SW/2 - 80)) < 50 then gameState = "menu"; playMusic("home")
            elseif math.abs(x - (SW/2))       < 50 then resetGame(); gameState = "play"
            elseif math.abs(x - (SW/2 + 80))  < 50 then gameState = "play" end
        end
    end
end

function spawnObject()
    local speedScale = 1 + (gameTime / 60) * 0.2

    -- احتمالات الكائنات الجديدة
    local rand = math.random()
    local oType
    if isNight then
        oType = "coffee"
    elseif rand < 0.04 then
        oType = "blueberry"
    elseif rand < 0.08 then
        oType = "orange"
    elseif rand < 0.12 then
        oType = "cranberry"
    elseif rand < 0.15 then
        oType = "watermelon_fruit"
    elseif rand < 0.18 then
        oType = "stone"
    elseif rand < 0.25 then
        oType = "cherry"
    elseif rand < 0.45 then
        oType = "coffee"
    else
        oType = "ice"
    end

    local o = {
        type = oType, x = math.random(50, SW-50), y = -60,
        vx = math.random(-30, 30), vy = (150 + math.random(20, 60)) * speedScale,
        opacity = 1, isFading = false,
        angle = math.random(0, 360), rotSpeed = math.random(-2, 2)
    }

    if     o.type == "cherry"           then o.img = imgs.cherry;        o.points = 25;  o.scale = 0.6
    elseif o.type == "coffee"           then o.img = imgs.coffee;        o.points = -20; o.scale = 0.6
    elseif o.type == "blueberry"        then o.img = imgs.blueberry;     o.points = 30;  o.scale = 0.6
    elseif o.type == "orange"           then o.img = imgs.orange;        o.points = 30;  o.scale = 0.6
    elseif o.type == "cranberry"        then o.img = imgs.cranberry;     o.points = 25;  o.scale = 0.6
    elseif o.type == "watermelon_fruit" then o.img = imgs.watermelon;    o.points = 50;  o.scale = 0.6
    elseif o.type == "stone"            then o.img = imgs.stones;        o.points = 0;   o.scale = 0.7
        -- الصخرة تسقط بسرعة عالية بدون حركة أفقية
        o.vx = 0
        o.vy = (500 + math.random(100, 200)) * speedScale
    else                                     o.img = imgs.ice;           o.points = 5;   o.scale = 0.6
    end

    o.w = math.floor(o.img:getWidth()  * o.scale)
    o.h = math.floor(o.img:getHeight() * o.scale)
    table.insert(objects, o)
end

function love.update(dt)
    if     gameState == "logo"  then updateLogo(dt)
    elseif gameState == "play"  then updateGame(dt)
    elseif gameState == "death" then updateDeath(dt) end

    -- التحقق من نتيجة الإعلان في أي حالة (لفتح الأكواب من Skin Menu)
    if adForSkin and _skinAdUnlockCup and pollAdReward() then
        unlockedCups[_skinAdUnlockCup] = true
        saveCups()
        newCupFlash      = { cupId = _skinAdUnlockCup, timer = 3.0 }
        skinBtnFlash     = true
        skinBtnFlashTimer = 5.0
        _skinAdUnlockCup = nil
        adForSkin        = false
        gameState        = "skin"
    end

    -- تبادل الأغنيتين أثناء اللعب
    if currentMusicState == "play" then
        if currentPlayTrack == 1 and not snds.musicPlay1:isPlaying() then
            currentPlayTrack = 2; snds.musicPlay2:play()
        elseif currentPlayTrack == 2 and not snds.musicPlay2:isPlaying() then
            currentPlayTrack = 1; snds.musicPlay1:play()
        end
    end

    -- تحديث وميض الكوب الجديد
    if newCupFlash then
        newCupFlash.timer = newCupFlash.timer - dt
        if newCupFlash.timer <= 0 then newCupFlash = nil end
    end

    -- تحديث وميض زر Skin
    if skinBtnFlash then
        skinBtnFlashTimer = skinBtnFlashTimer - dt
        if skinBtnFlashTimer <= 0 then
            skinBtnFlash = false
            skinBtnFlashTimer = 0
        end
    end
end

function loadHighScore()
    local f = io.open(HS_PATH, "r")
    if f then highScore = tonumber(f:read("*l")) or 0; f:close() end
end

function saveScore()
    if score > highScore then
        highScore = score
        local f = io.open(HS_PATH, "w")
        if f then f:write(tostring(highScore)); f:close() end
    end
end

function resetGame()
    score, lives, cherryCount, gameTime, cycleTimer,
    objects, floatingTexts, difficulty, shakeTimer,
    isNight, spawnTimer, lastDifficultyLevel = 0, 5, 0, 0, 0, {}, {}, 1, 0, false, 0, 1
    adUsedThisRound   = false
    adNotAvailable    = false
    adWaitingForResult = false
    activeEffects = { noCoffee = 0, speed = 0, doubleScore = 0, rockShield = 0 }
    touchActive = false; touchX = nil
    -- إعادة تعيين متتبع التحديات
    challengeTrack.iceThisRound    = 0
    challengeTrack.coffeeAvoided   = 0
    challengeTrack.rockDodged      = 0
    challengeTrack.nightScore      = 0
    challengeTrack.cherryThisRound = 0
    challengeTrack.surviveTime     = 0
    checkCupUnlocks()
    updatePlayerCup()
    playMusic("play")
end
