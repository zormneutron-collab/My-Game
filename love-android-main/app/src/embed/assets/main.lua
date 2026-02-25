love.graphics.setDefaultFilter("nearest", "nearest")

local gameState = "logo"
local score, lives, highScore = 0, 5, 0
local isNight = false
local cycleTimer, difficulty, gameTime, cherryCount = 0, 1, 0, 0
local objects, imgs, snds = {}, {}, {}
local floatingTexts = {}
local font_big, font_small
local shakeTimer, spawnTimer = 0, 0
local lastDifficultyLevel = 1

local PLAYER_SPEED = 820

-- ===== متغيرات اللوجو =====
local logoAlpha    = 0
local logoTimer    = 0
local logoState    = "fadein"  -- fadein / hold / fadeout
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
local adNotAvailable     = false  -- الإعلان غير متاح حالياً

-- ===== مسارات التواصل مع Java =====
local AD_CMD_PATH    = "/data/data/com.pixel.juice/files/ad_command.txt"
local AD_RESULT_PATH = "/data/data/com.pixel.juice/files/ad_result.txt"

local function writeAdCommand(cmd)
    local f = io.open(AD_CMD_PATH, "w")
    if f then
        f:write(cmd); f:close()
    else
    end
end

local function readAdResult()
    local f = io.open(AD_RESULT_PATH, "r")
    if not f then return nil end
    local result = f:read("*l")
    f:close()
    os.remove(AD_RESULT_PATH)
    return result
end

-- ===== استدعاء showRewardedAd() في Java =====
local function callShowAd()
    if love.system.getOS() ~= "Android" then
        return
    end
    writeAdCommand("show")
    adWaitingForResult = true
    adNotAvailable     = false
end

-- ===== فحص هل Java منحت المكافأة أو رفضت؟ =====
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

-- ===== تشغيل شاشة الموت =====
local function triggerDeath()
    saveScore()
    objects        = {}
    floatingTexts  = {}
    deathTimer     = 0
    deathCountdown = 10
    adWaitingForResult = false
    adNotAvailable     = false
    _deathAdBtn, _deathExitBtn = nil, nil
    gameState = "death"
end

function love.load()
    font_big   = love.graphics.newFont(38)
    font_small = love.graphics.newFont(18)

    imgs.player    = love.graphics.newImage("image/glass.png")
    imgs.bgDay     = love.graphics.newImage("image/background.png")
    imgs.bgNight   = love.graphics.newImage("image/night_background.png")
    imgs.life      = love.graphics.newImage("image/life.png")
    imgs.btnPlay   = love.graphics.newImage("image/button_play.png")
    imgs.btnInfo   = love.graphics.newImage("image/button_info.png")
    imgs.btnPause  = love.graphics.newImage("image/pause.png")
    imgs.ice       = love.graphics.newImage("image/ice.png")
    imgs.cherry    = love.graphics.newImage("image/cherry.png")
    imgs.coffee    = love.graphics.newImage("image/coffee.png")
    imgs.uiPanel   = love.graphics.newImage("image/ui.png")
    imgs.btnContinue = love.graphics.newImage("image/button_ continue.png")
    imgs.btnRestart  = love.graphics.newImage("image/button_return.png")
    imgs.btnHome     = love.graphics.newImage("image/button_back.png")
    imgs.logo        = love.graphics.newImage("image/logo.png")

    snds.ice      = love.audio.newSource("Sound/pick_ice.wav",    "static")
    snds.coffee   = love.audio.newSource("Sound/pick_coffe.wav",  "static")
    snds.cherry   = love.audio.newSource("Sound/Pick_cherry.wav", "static")
    snds.loseLife = love.audio.newSource("Sound/lost_life.wav",   "static")
    snds.levelUp  = love.audio.newSource("Sound/level_up.wav",    "static")
    snds.warning  = love.audio.newSource("Sound/low_life.wav",    "static")
    snds.click    = love.audio.newSource("Sound/click.wav",       "static")
    snds.night    = love.audio.newSource("Sound/night.wav",       "static")
    snds.day      = love.audio.newSource("Sound/start_day.wav",   "static")

    SW, SH = love.graphics.getDimensions()
    player = {
        x = SW/2, y = SH - 160,
        w = imgs.player:getWidth(), h = imgs.player:getHeight(),
        speed = 850
    }
    loadHighScore()
end

-- ===== تحديث شاشة اللوجو =====
local function updateLogo(dt)
    logoTimer = logoTimer + dt
    if logoState == "fadein" then
        logoAlpha = math.min(1, logoTimer / LOGO_FADEIN)
        if logoTimer >= LOGO_FADEIN then
            logoTimer = 0; logoState = "hold"
        end
    elseif logoState == "hold" then
        logoAlpha = 1
        if logoTimer >= LOGO_HOLD then
            logoTimer = 0; logoState = "fadeout"
        end
    elseif logoState == "fadeout" then
        logoAlpha = math.max(0, 1 - logoTimer / LOGO_FADEOUT)
        if logoTimer >= LOGO_FADEOUT then
            gameState = "menu"
        end
    end
end

-- ===== رسم شاشة اللوجو =====
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
    difficulty = 1 + (gameTime / 60) * 0.30
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

    if love.mouse.isDown(1) then
        local mx = love.mouse.getX()
        if mx < SW/2 then
            player.x = player.x - PLAYER_SPEED * dt
        else
            player.x = player.x + PLAYER_SPEED * dt
        end
    end
    player.x = math.max(player.w/2, math.min(SW - player.w/2, player.x))

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnObject()
        local spawnRate = math.max(0.18, math.random(0.4, 1.1) / (1 + (gameTime / 60) * 0.3))
        spawnTimer = spawnRate
    end

    for i = #objects, 1, -1 do
        local o = objects[i]
        if not o.isFading then
            o.y = o.y + o.vy * dt
            o.x = o.x + o.vx * dt

            if o.x - o.w/2 < 0 then
                o.x  = o.w/2
                o.vx = math.abs(o.vx)
            elseif o.x + o.w/2 > SW then
                o.x  = SW - o.w/2
                o.vx = -math.abs(o.vx)
            end

            local hitWidth = player.w + 10
            if (o.x > player.x - hitWidth/2) and (o.x < player.x + hitWidth/2) and
               (o.y + o.h/2 > player.y) and (o.y < player.y + 40) then
                o.isFading = true; processScore(o)
            end
        else
            o.x       = o.x + (player.x - o.x) * 15 * dt
            o.y       = o.y + (player.y + 40 - o.y) * 15 * dt
            o.opacity = o.opacity - dt * 8
            if o.opacity <= 0 then table.remove(objects, i) end
        end

        if o.y > SH then
            if not isNight and o.type == "ice" and not o.isFading then
                lives = lives - 1; shakeTimer = 0.2; snds.loseLife:play()
                if lives == 1 then snds.warning:play() end
                if lives <= 0 then triggerDeath(); return end
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
    -- فحص مكافأة الإعلان في كل frame
    if pollAdReward() then
        objects         = {}
        floatingTexts   = {}
        spawnTimer      = 1.0
        lives           = 1
        adUsedThisRound = true
        gameState       = "play"
        return
    end

    deathTimer     = deathTimer + dt
    deathCountdown = math.ceil(10 - deathTimer)
    if deathCountdown <= 0 then
        gameState = "menu"
    end
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

    -- عداد تنازلي
    local cc = deathCountdown <= 3 and {1, 0.22, 0.22} or {1, 0.85, 0.15}
    love.graphics.setFont(font_big)
    love.graphics.setColor(cc[1], cc[2], cc[3], 1)
    love.graphics.printf(tostring(math.max(deathCountdown, 0)), panelX, panelY + 154, panelW, "center")

    -- رسالة الحالة تحت العداد
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

    -- زر الإعلان
    local adBtnW = panelW - 60
    local adBtnH = 64
    local adBtnX = panelX + 30
    local adBtnY = panelY + 246

    if adUsedThisRound then
        -- تم استخدام الإعلان — زر رمادي معطّل
        love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.printf("No more chances this round", adBtnX, adBtnY + 22, adBtnW, "center")
        _deathAdBtn = nil

    elseif adNotAvailable then
        -- الإعلان غير متاح — زر برتقالي مع رسالة
        love.graphics.setColor(0.35, 0.18, 0.05, 1)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1.0, 0.55, 0.1, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1, 0.85, 0.5, 1)
        love.graphics.printf("Ad not ready — Tap to retry", adBtnX, adBtnY + 22, adBtnW, "center")
        -- لا يزال قابلاً للضغط لإعادة المحاولة
        _deathAdBtn = { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }

    else
        -- الزر الطبيعي
        love.graphics.setColor(adWaitingForResult and 0.3 or 0.12,
                               adWaitingForResult and 0.3 or 0.68,
                               adWaitingForResult and 0.3 or 0.32, 1)
        love.graphics.rectangle("fill", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(0.18, 1.0, 0.48, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", adBtnX, adBtnY, adBtnW, adBtnH, 14, 14)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            adWaitingForResult and "Waiting for reward..." or "Watch Ad & Get 1 Life",
            adBtnX, adBtnY + 22, adBtnW, "center")
        _deathAdBtn = adWaitingForResult and nil
                      or { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }
    end

    -- زر الخروج
    local exBtnW = panelW - 60
    local exBtnH = 54
    local exBtnX = panelX + 30
    local exBtnY = adBtnY + adBtnH + 16

    love.graphics.setColor(0.32, 0.10, 0.10, 1)
    love.graphics.rectangle("fill", exBtnX, exBtnY, exBtnW, exBtnH, 14, 14)
    love.graphics.setColor(0.9, 0.18, 0.18, 0.75)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", exBtnX, exBtnY, exBtnW, exBtnH, 14, 14)
    love.graphics.setColor(1, 0.82, 0.82, 1)
    love.graphics.printf("Exit to Menu", exBtnX, exBtnY + 17, exBtnW, "center")
    _deathExitBtn = { x = exBtnX, y = exBtnY, w = exBtnW, h = exBtnH }
end

function processScore(o)
    local col = {1, 1, 1}
    if o.type == "coffee" then
        score = math.max(0, score - 20); col = {1, 0.2, 0.2}
        snds.coffee:stop(); snds.coffee:play()
    elseif o.type == "cherry" then
        score = score + 25; cherryCount = cherryCount + 1; col = {0.2, 1, 0.2}
        snds.cherry:stop(); snds.cherry:play()
        if cherryCount >= 4 then lives = math.min(lives + 1, 5); cherryCount = 0 end
    else
        score = score + 5; col = {0.4, 0.8, 1}
        snds.ice:stop(); snds.ice:play()
    end
    table.insert(floatingTexts, {
        text = (o.points > 0 and "+" or "") .. o.points,
        x = player.x - 20, y = player.y - 30, timer = 1.2, color = col
    })
end

function love.draw()
    if gameState == "logo" then
        drawLogo()
        return
    end

    if gameState == "play" and shakeTimer > 0 then
        love.graphics.translate(math.random(-6, 6), math.random(-6, 6))
    end

    local bg = isNight and imgs.bgNight or imgs.bgDay
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, SW / bg:getWidth(), SH / bg:getHeight())

    if gameState == "play" or gameState == "pause" then
        love.graphics.draw(imgs.player, player.x, player.y, 0, 1, 1, player.w/2, 0)
        for _, o in ipairs(objects) do
            love.graphics.setColor(1, 1, 1, o.opacity)
            love.graphics.draw(o.img, o.x, o.y, o.angle, 1, 1, o.w/2, o.h/2)
        end
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
        love.graphics.draw(imgs.player, player.x, player.y, 0, 1, 1, player.w/2, 0)
        drawDeathScreen()

    elseif gameState == "menu" then drawMenu()
    elseif gameState == "info"  then drawInfo()
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
end

local function handleDeathClick(x, y)
    -- زر الإعلان
    if not adUsedThisRound and not adWaitingForResult and _deathAdBtn and
       x >= _deathAdBtn.x and x <= _deathAdBtn.x + _deathAdBtn.w and
       y >= _deathAdBtn.y and y <= _deathAdBtn.y + _deathAdBtn.h then
        snds.click:play()
        adNotAvailable = false  -- أعد الضبط قبل المحاولة
        callShowAd()
        return
    end

    -- زر الخروج
    if _deathExitBtn and
       x >= _deathExitBtn.x and x <= _deathExitBtn.x + _deathExitBtn.w and
       y >= _deathExitBtn.y and y <= _deathExitBtn.y + _deathExitBtn.h then
        snds.click:play()
        adWaitingForResult = false
        adNotAvailable     = false
        gameState = "menu"
        return
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and gameState == "info" then
        infoDragStartY      = y
        infoDragScrollStart = infoScrollY
    end
end

function love.mousemoved(x, y, dx, dy)
    if gameState == "info" and infoDragStartY then
        local delta = infoDragStartY - y
        infoScrollY = math.max(0, math.min(infoMaxScroll, infoDragScrollStart + delta))
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end

    infoDragStartY = nil

    if gameState == "death" then
        handleDeathClick(x, y)

    elseif gameState == "menu" then
        if math.abs(x - SW/2) < 100 then
            snds.click:play()
            if     y > SH*0.45 and y < SH*0.55 then resetGame(); gameState = "play"
            elseif y > SH*0.60 and y < SH*0.70 then
                infoScrollY = 0
                gameState = "info"
            end
        end

    elseif gameState == "info" then
        if _infoBtnBack and
           x >= _infoBtnBack.x and x <= _infoBtnBack.x + _infoBtnBack.w and
           y >= _infoBtnBack.y and y <= _infoBtnBack.y + _infoBtnBack.h then
            snds.click:play(); gameState = "menu"
        end

    elseif gameState == "play" then
        if x > SW - 90 and y < 90 then snds.click:play(); gameState = "pause" end

    elseif gameState == "pause" then
        local uiY  = SH/2
        local btnY = uiY + (imgs.uiPanel:getHeight() * 8 * 0.15)
        if math.abs(y - btnY) < 60 then
            snds.click:play()
            if     math.abs(x - (SW/2 - 80)) < 50 then gameState = "menu"
            elseif math.abs(x - (SW/2))       < 50 then resetGame(); gameState = "play"
            elseif math.abs(x - (SW/2 + 80))  < 50 then gameState = "play" end
        end
    end
end

function spawnObject()
    local speedScale = 1 + (gameTime / 60) * 0.2
    local oType = isNight and "coffee"
               or (math.random() < 0.07 and "cherry"
               or (math.random() < 0.25  and "coffee" or "ice"))
    local o = {
        type = oType, x = math.random(50, SW-50), y = -60,
        vx = math.random(-30, 30), vy = (150 + math.random(20, 60)) * speedScale,
        opacity = 1, isFading = false,
        angle = math.random(0, 360), rotSpeed = math.random(-2, 2)
    }
    if     o.type == "cherry" then o.img = imgs.cherry; o.points =  25
    elseif o.type == "coffee" then o.img = imgs.coffee; o.points = -20
    else                           o.img = imgs.ice;    o.points =   5 end
    o.w, o.h = o.img:getWidth(), o.img:getHeight()
    table.insert(objects, o)
end

function love.update(dt)
    if     gameState == "logo"  then updateLogo(dt)
    elseif gameState == "play"  then updateGame(dt)
    elseif gameState == "death" then updateDeath(dt) end
end

local HS_PATH = "/data/data/com.pixel.juice/files/highscore.txt"

function loadHighScore()
    local f = io.open(HS_PATH, "r")
    if f then
        highScore = tonumber(f:read("*l")) or 0
        f:close()
    end
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
    adUsedThisRound  = false
    adNotAvailable   = false
    adWaitingForResult = false
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

    local font_info = love.graphics.newFont(14)

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

    local function divider()
        ty = ty + sh
        love.graphics.setColor(1, 1, 1, 0.10)
        love.graphics.rectangle("fill", tx + 10, ty, tw - 20, 1)
        ty = ty + sh
    end

    local font_title = love.graphics.newFont(26)
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
    love.graphics.printf("Developed by  Mamdouh Ibrahim", tx, ty, tw, "center")
    ty = ty + lh

    divider()
    section("CONTROLS")
    line("Tap LEFT  ->  move cup left")
    line("Tap RIGHT  ->  move cup right")
    line("Hold to keep moving")

    divider()
    section("ITEMS")
    line("ICE CUBE      +5 pts      catch it",   0.50, 0.90, 1.00)
    line("COFFEE BEAN   -20 pts     avoid it",   1.00, 0.40, 0.40)
    line("CHERRY        +25 pts     4 = 1 life", 0.40, 1.00, 0.50)

    divider()
    section("LIVES")
    line("You start with 5 lives")
    line("Miss an ice cube  ->  lose 1 life")
    line("Lose all  ->  game over")
    line("Watch an ad  ->  second chance")

    divider()
    section("DIFFICULTY")
    line("Speed increases over time")
    line("Night: only coffee falls")
    line("No speed limit — push your limits")

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
    love.graphics.printf("Tap to Back", btnX, btnY + 14, btnW, "center")

    _infoBtnBack = { x = btnX, y = btnY, w = btnW, h = btnH }
end

function drawMenu()
    local btnW = imgs.btnPlay:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.btnPlay, SW/2, SH*0.5,  0, 1, 1, btnW/2, imgs.btnPlay:getHeight()/2)
    love.graphics.draw(imgs.btnInfo, SW/2, SH*0.65, 0, 1, 1, btnW/2, imgs.btnInfo:getHeight()/2)

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
    love.graphics.printf(label,  boxX, boxY + 8,                           boxW, "center")
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf(numStr, boxX, boxY + 8 + font_big:getHeight() + 6, boxW, "center")
end
