function love.conf(t)
    t.modules.joystick = false
    t.modules.physics = false
    t.externalstorage = true
    t.version = "12.0"
    t.window.display = 0

    -- ✅ أضف هذا:
    t.window.width = 480
    t.window.height = 854
end
