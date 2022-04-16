--[[animations = {
    defaultAnim = "hi.png",
    anim0 = {
        framerate = 2,
        playback = "PLAYBACK_LOOP_FORWARD",
        frames = {
            "frame0.png",
            "frame1.png"
        }
    }
}

function initialize()
    getInput()
end

function loadResources(mod_dir)
    local files = {
        "hi.png",
        "frame0.png",
        "frame1.png",
        animations = animations
    }
    return files
end

function input(id, action)
    if id == "MOUSE_LEFT" and action.pressed then
        print("hello")
        play_anim(anim0, {"default"})
    end
    if id == "MOUSE_LEFT" and action.released then
        print("goodbye")
        cancel_anim()
    end
    if id == "SPACE" and action.pressed then
        broadcast("greetings")
    end
    if id == "LEFT" then
        move_by("x", -20)
    end
end

function upd(dt)
    --nothing lol
end

--[[
info - lua table
elements:
id - number ID of transmitter (order in JSON file)
transmitterType - type of the transmitter
timesCalled - times called in all

function onEvent(id, info)
    if id == "hello" then
        print("Hello, " .. info.transmitterType .. " with the ID of " .. info.id .."! You've said this ".. info.timesCalled .. " times!")
        message(info.id, "replied", {})
    end
end

function onMsg(id, message, sender)
    print("Message from " .. sender)
    pprint(message)
end]]