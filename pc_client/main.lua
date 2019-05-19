local sp   = require "lib/rs232"
local json = require "lib/json"


local serial_port = "ttyUSB0"


local data = {}
local font = nil
local fontY = 30
local serial_start = false

local floor = math.floor
local pack  = function(format, ...) return love.data.pack("string", format, ...) end
local upack = function(datastring, format) return 0, love.data.unpack(format, datastring) end


function love.load()

	gr=love.graphics
	kb=love.keyboard
	mo=love.mouse
	js=love.joystick

	for k,v in ipairs(sp.ports()) do print(k,v) end

	setColor = function(r,g,b,a)
		if not a then a = 255 end
		gr.setColor(r/255,g/255,b/255,a/255)
	end

	-- love.joystick.loadGamepadMappings("gamecontrollerdb.map")

	gamepadText = {}

	local tab = love.filesystem.getDirectoryItems("media/")

	for k, v in ipairs(tab) do
		v = v:gsub(".png$","")
		v = v:gsub("360_","")
		gamepadText[v] = gr.newImage("media/360_"..v..".png")
	end

	avatar = gr.newImage("lib/avatarBig500x500.png")

	gamepadKey = {
		"a",
		"b",
		"x",
		"y",
		"back",
		"guide",
		"start",
		"leftstick",
		"rightstick",
		"leftshoulder",
		"rightshoulder",
		"dpup",
		"dpdown",
		"dpleft",
		"dpright"
	}

	gamepadAxis = {
		"leftx",
		"lefty",
		"rightx",
		"righty",
		"triggerleft",
		"triggerright"
	}


	hatDir = {
		"c",
		"d",
		"l",
		"ld",
		"lu",
		"r",
		"rd",
		"ru",
		"u"
	}

	hatDirRev = {
		d = 4,
		l = 8,
		r = 2,
		u = 1
	}

	ppm = {
		1500,
		1500,
		1500,
		1500,
		1500,
		1500
	}

	ppm_set = {}


	win={w=gr.getWidth(),h=gr.getHeight()}-- Window.
	--mo.setVisible(false)
	main_font = gr.newFont(math.floor(15))
	min_font = gr.newFont(math.floor(12))
	max_font = gr.newFont(math.floor(28))
	gr.setFont(main_font)

	current_joy = nil

	gr.setLineStyle("rough")
	-- gr.setBackgroundColor(0,31/255,31/255)

	joysticks = {}

	update_timer = 0

	love.joystick.loadGamepadMappings("gamecontrollerdb.map")
	love.graphics.setNewFont(50)
	font = love.graphics.getFont()
	fontY = font:getHeight()

	update_timer = 0
	msg_disp = ""
	love.graphics.setFont(love.graphics.newFont(32))

	local contents = love.filesystem.read( "save.json" )
	if contents then
		ppm_set = json.decode(contents).ppm_set
		serial_port = json.decode(contents).serial_port
	end

end

function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

function keymapExtract(line)
	local t = split(line, ",")
	local guid = t[1]
	local name = t[2]
	-- for k, v in ipairs(t) do print(k,v) end
	local data = {}
	for i=3, #t-1 do
		local key, value = string.match(t[i], '(.*):(.*)')
		-- print(i, key, value)
		data[key] = value
	end
	return guid, name, data
end


function keymapToTab(sguid)
	local str = love.joystick.saveGamepadMappings()

	if sguid then
		for line in (str..'\n'):gmatch('(.-)\r?\n') do
			local guid, name, data = keymapExtract(line)
			-- print(sguid, guid, line)
			if sguid == guid then
				return guid, name, data
			end
		end
		return nil
	else
		local ret = {}
		for line in (str..'\n'):gmatch('(.-)\r?\n') do
			local guid, name, data = keymapExtract(line)
			table.insert(ret, {guid = guid, name = name, data = data})
		end
		return ret
	end
end

function keymapClear(guid, name)
	love.joystick.loadGamepadMappings(guid..","..name..",")
end

function keymapSetKey(guid, name, key, type, value, hatdir)
	local guid, name, data = keymapToTab(guid or current_joy:getGUID())
	if not guid then
		guid = current_joy:getGUID()
		name = current_joy:getName()
		print("keymapSetKey",guid,name,key,type,value)
	end

	data = data or {}

	print("keymapSetKey",guid,name,key,type,value)

	-- print(data[key])

	if key == "triggerleft" then key = "lefttrigger" end
	if key == "triggerright" then key = "righttrigger" end

	if type == "button" then
		data[key] = "b"..value
	elseif type == "hat" then
		data[key] = "h"..value.."."..hatdir
	elseif type == 'axis' then
		data[key] = "a"..value
	else
		data[key] = nil
	end

	print(data[key])
	print(tabToKeymap(guid, name, data))

	love.joystick.loadGamepadMappings(tabToKeymap(guid, name, data))
end

function tabToKeymap(guid, name, data)
	str = guid..","..name..","
	for k, v in pairs(data) do
		str = str..k..":"..v..","
	end
	return str
end

function isButton(key)
	for k,v in ipairs(gamepadKey) do
		if v == key then
			return true
		end
	end
	return false
end

function getJoyIndex(joy)
	for k,v in ipairs(joysticks) do
		if joy == v then
			return k
		end
	end
end

function love.joystickadded(joy)
	print("add joy", joy)
	table.insert(joysticks,joy)
	if not current_joy then current_joy = joy end
end

function love.joystickremoved(joy)
	print("remove joy", joy)
	table.remove(joysticks,getJoyIndex(joy))
	if current_joy == joy then
		current_joy = nil
		for k,v in ipairs(joysticks) do
			current_joy = v
		end
	end
end


function love.update(dt)
	if modif then
		modif_time = modif_time + dt
		if modif_time > 5 then
			modif_time = 0
			modif = false
		end
	end
	update_timer = update_timer + dt

	if update_timer > 0.020 then -- ( 40Hz = 0.025)

		update_timer = 0

		for index=1,6 do
			local i = 1
			local t = {}
			for k,v in pairs(joysticks) do
				t[#t+1] = v
			end

			if ppm_set[index] and t[ppm_set[index].joy] then
				if ppm_set[index].type == "axis" then
					ppm[index] = 500 * (t[ppm_set[index].joy]:getAxis(ppm_set[index].value)*(ppm_set[index].reverse and -1 or 1)) + 1500
				elseif ppm_set[index].type == "button" then
					if (ppm_set[index].reverse) then
						ppm[index] = 1000 + ((t[ppm_set[index].joy]:isDown(ppm_set[index].value)) and 0 or 1000)
					else
						ppm[index] = 1000 + ((t[ppm_set[index].joy]:isDown(ppm_set[index].value)) and 1000 or 0)
					end
				elseif ppm_set[index].type == "hat" then
					if (ppm_set[index].reverse) then
						ppm[index] = 1000 + ((t[ppm_set[index].joy]:getHat(ppm_set[index].value)==ppm_set[index].dir) and 0 or 1000)
					else
						ppm[index] = 1000 + ((t[ppm_set[index].joy]:getHat(ppm_set[index].value)==ppm_set[index].dir) and 1000 or 0)
					end
				end
			end
		end

		if serial_start then
			serial_start:write(pack("B<H<H<H<H<H<H",42,ppm[1],ppm[2],ppm[3],ppm[4],ppm[5],ppm[6]), 13)
		end
		update_timer = 0
	end
end


function love.draw()
	setColor(255,255,255)
	gr.setLineWidth(1)

	-- drawJoyList(10, 10)

	local i = 1
	drawSerial(0,0)
	drawSerialSet(250,10)
	drawSerialStart(300,10)
	drawPPM(0,60)
	for k,v in ipairs(joysticks) do
		-- print(k,v)
		drawInfo((400*i),0, v)
		drawAxis((400*i), 60, v)
		drawButton((400*i), 250 + 60,v )
		drawHat((400*i), 400 + 60, v)
		drawOrderSet((400*i), 400 + 60 + 70, v)
		i = i + 1
	end

	love.graphics.draw(avatar, 80, 320, 0, .5, .5)
	love.graphics.setFont(max_font)
	love.graphics.print("Spectre", 145, 550)
	love.graphics.setFont(main_font)

	if modif then
		drawPopup(0,0)
	end

	if serial_modif then
		drawPopupSerial(0,0)
	end
end

function drawPopup()
	setColor(0,0,0,230)
	gr.rectangle("fill",0,0,win.w,win.h)
	setColor(255,255,255,255)
	local x = win.w / 2 - 600/2
	local y = win.h / 2 - 150/2
	setColor(200,200,200)
	gr.rectangle("fill", x, y, 600, 150)

	setColor(0,0,0,255)
	gr.rectangle("line", x, y, 600, 150)
	setColor(50,50,50)
	love.graphics.print("Press the button or the axis you want to use for PPM: "..modif, x + 20, y + 20)
	setColor(50,50,50)
	-- love.graphics.print(modif_type, x + 20, y + 40)
	love.graphics.print("for cancel press ESC or wait "..math.ceil(5 - modif_time).." seconds", x + 20, y + 60)
end

function drawPopupSerial()
	setColor(0,0,0,230)
	gr.rectangle("fill",0,0,win.w,win.h)
	setColor(255,255,255,255)
	local x = win.w / 2 - 600/2
	local y = win.h / 2 - 150/2
	setColor(200,200,200)
	gr.rectangle("fill", x, y, 600, 150)

	setColor(0,0,0,255)
	gr.rectangle("line", x, y, 600, 150)
	setColor(50,50,50)
	love.graphics.print("Serial port: '"..serial_port.."'", x + 20, y + 20)
end

function drawIcone(x,y, name)
	if gamepadText[name] then
		if name == 'guide' then
			love.graphics.draw(gamepadText[name], x, y, nil, 0.78, 0.78)
		else
			love.graphics.draw(gamepadText[name], x, y, nil , 0.5, 0.5)
		end
	end
end

function drawGamepad(x,y)

	setColor(255,255,255)
	gr.rectangle("line", x, y, 750, 390)

	x = x - 20
	y = y - 20

	gr.draw(gamepadText.Gamepad, x, y)

	if current_joy:isGamepadDown("a") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.a, x + 440, y + 147, 0, 0.5, 0.5)

	if current_joy:isGamepadDown("b") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.b, x + 484, y + 103, 0, 0.5, 0.5)

	if current_joy:isGamepadDown("y") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.y, x + 440, y + 59, 0, 0.5, 0.5)

	if current_joy:isGamepadDown("x") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.x, x + 396, y + 103, 0, 0.5, 0.5)

	if current_joy:isGamepadDown("leftstick") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	local axis_x = current_joy:getGamepadAxis("leftx")
	local axis_y = current_joy:getGamepadAxis("lefty")

	gr.draw(gamepadText.leftstick, x + 81 + axis_x * 12, y + 77 + axis_y * 12)

	if current_joy:isGamepadDown("rightstick") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	local axis_x = current_joy:getGamepadAxis("rightx")
	local axis_y = current_joy:getGamepadAxis("righty")
	gr.draw(gamepadText.rightstick, x + 330 + axis_x * 12, y + 179 + axis_y * 12)

	setColor(255,255,255)
	gr.draw(gamepadText.Dpad, x + 164, y + 177)
	love.graphics.setBlendMode("lighten","premultiplied")
	if current_joy:isGamepadDown("dpdown") then gr.draw(gamepadText.dpdown, x + 164, y + 177) end
	if current_joy:isGamepadDown("dpup") then gr.draw(gamepadText.dpup, x + 164, y + 177) end
	if current_joy:isGamepadDown("dpleft") then gr.draw(gamepadText.dpleft, x + 164, y + 177) end
	if current_joy:isGamepadDown("dpright") then gr.draw(gamepadText.dpright, x + 164, y + 177) end
	love.graphics.setBlendMode("alpha")

	if current_joy:isGamepadDown("back") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.back, x + 213, y + 111, 0, 0.5, 0.5)

	if current_joy:isGamepadDown("start") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.start, x + 337, y + 111, 0, 0.5, 0.5)


	if current_joy:isGamepadDown("guide") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.guide, x + 270, y + 101)

	if current_joy:isGamepadDown("leftshoulder") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.leftshoulder, x + 545 + 22, y - 5)

	if current_joy:isGamepadDown("rightshoulder") then
		setColor(100,100,100)
	else
		setColor(255,255,255)
	end
	gr.draw(gamepadText.rightshoulder, x + 645 + 22, y - 5)

	setColor(255,255,255)

	local axis_l = current_joy:getGamepadAxis("triggerleft")
	local axis_r = current_joy:getGamepadAxis("triggerright")

	setColor(255 - math.abs(axis_l*200), 255 - math.abs(axis_l*200), 255 - math.abs(axis_l*200))
	gr.draw(gamepadText.triggerleft, x + 22 + 550, y + 70)

	setColor(axis_l * 255, 255 - math.abs(axis_l*255), -(axis_l * 255))
	gr.rectangle("fill", x + 22 + 600, y + 170 - 75 * axis_l + 75, 30, 75 * axis_l)

	setColor(255,255,255)
	gr.rectangle("line", x + 22 + 600, y + 170, 30, 75)

	local val = math.floor(axis_l * 100).."%"
	gr.print(val, x + 22 + 635 - main_font:getWidth(val), y + 250)

	setColor(255 - math.abs(axis_r*200), 255 - math.abs(axis_r*200), 255 - math.abs(axis_r*200))
	gr.draw(gamepadText.triggerright, x + 22 + 650, y + 70)

	setColor(axis_r * 255, 255 - math.abs(axis_r*255), -(axis_r * 255))
	gr.rectangle("fill", x + 22 + 670, y + 170 - 75 * axis_r + 75, 30, 75 * axis_r)

	setColor(255,255,255)
	gr.rectangle("line", x + 22 + 670, y + 170, 30, 75)

	local val = math.floor(axis_r * 100).."%"
	gr.print(val, x + 22 + 700 - main_font:getWidth(val), y + 250)

	if current_joy:isVibrationSupported() then
		setColor(230,230,230)
		gr.rectangle("fill", x + 600, y + 270, 145, 50)
		setColor(0,0,0)
		gr.rectangle("line", x + 600, y + 270, 145, 50)
		love.graphics.print( "Test Vibration 1", x + 610, y + 270 + 15)

		setColor(230,230,230)
		gr.rectangle("fill", x + 600, y + 270 + 60, 145, 50)
		setColor(0,0,0)
		gr.rectangle("line", x + 600, y + 270 + 60, 145, 50)
		love.graphics.print( "Test Vibration 2", x + 610, y + 270 + 60 + 15)
	end
end

function drawGamepadInput(x,y)

	gr.rectangle("line", x, y, 582, 302)

	drawnSingleInput(x+1, y+1, gamepadText.a, "a", 0.5)
	drawnSingleInput(x+1, y + 1 + 50, gamepadText.b, "b", 0.5)
	drawnSingleInput(x+1, y + 1 + 100, gamepadText.x, "x", 0.5)
	drawnSingleInput(x+1, y + 1 + 150, gamepadText.y, "y", 0.5)
	drawnSingleInput(x+1, y + 1 + 200, gamepadText.start, "start", 0.5)
	drawnSingleInput(x+1, y + 1 + 250, gamepadText.back, "back", 0.5)

	drawnSingleInput(x+ 1 + 145, y + 1, gamepadText.guide, "guide", 0.78)
	drawnSingleInput(x+ 1 + 145, y + 1 + 50, gamepadText.leftstick, "leftstick", 0.5)
	drawnSingleInput(x+ 1 + 145, y + 1 + 100, gamepadText.rightstick, "rightstick", 0.5)

	drawnSingleInput(x+ 1 + 145, y + 1 + 150, gamepadText.leftshoulder, "leftshoulder", 0.5)
	drawnSingleInput(x+ 1 + 145, y + 1 + 200, gamepadText.rightshoulder, "rightshoulder", 0.5)


	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 0, gamepadText.leftx, "leftx", 0.5)
	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 50, gamepadText.lefty, "lefty", 0.5)

	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 100, gamepadText.rightx, "rightx", 0.5)
	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 150, gamepadText.righty, "righty", 0.5)

	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 200, gamepadText.triggerleft, "triggerleft", 0.5, 0.5, true)
	drawnSingleInput(x+ 1 + 145 * 2, y + 1 + 250, gamepadText.triggerright, "triggerright", 0.5, 0.5, true)

	drawnSingleInput(x+ 1 + 145 * 3, y + 1 + 50 * 0, gamepadText.dpup, "dpup", 0.5)
	drawnSingleInput(x+ 1 + 145 * 3, y + 1 + 50 * 1, gamepadText.dpdown, "dpdown", 0.5)
	drawnSingleInput(x+ 1 + 145 * 3, y + 1 + 50 * 2, gamepadText.dpleft, "dpleft", 0.5)
	drawnSingleInput(x+ 1 + 145 * 3, y + 1 + 50 * 3, gamepadText.dpright, "dpright", 0.5)
end

function drawnSingleInput(x, y, img, input, rx, ry, color)
	setColor(200,200,200)
	gr.rectangle("fill", x, y, 145, 50)

	setColor(0,0,0)
	gr.rectangle("line", x, y, 145, 50)

	local inputtype, inputindex, hatdirection = current_joy:getGamepadMapping(input)
	setColor(50,50,50)
	if inputtype == "button" then
		gr.print(inputindex and ("Button_"..inputindex-1), x + 55, y + 16)
		if current_joy:isDown(inputindex) then
			setColor(100,100,100)
		else
			setColor(255,255,255)
		end
	elseif inputtype == "axis" then
		local axis_val = current_joy:getGamepadAxis(input)
		setColor(50,50,50)
		gr.print(inputindex and ("Axis_"..inputindex-1), x + 55, y + 16)

		if input == 'triggerleft' or input == 'triggerright' then
			setColor(axis_val * 255, 255 - math.abs(axis_val*255), -(axis_val * 255))
			gr.rectangle("fill", x + 120, y + 5 - (axis_val * 40) + 40, 20, 40 * axis_val)
		else
			setColor(axis_val * 255, 255 - math.abs(axis_val*255), -(axis_val * 255))
			gr.rectangle("fill", x + 120, y + 5 - axis_val * 20 + 20, 20, 20 * axis_val)
		end


		setColor(255,255,255)
		gr.rectangle("line", x + 120, y + 5, 20, 40)
		if color then
			setColor(255 - math.abs(axis_val*200), 255 - math.abs(axis_val*200), 255 - math.abs(axis_val*200))
		else
			setColor(255,255,255)
		end
	elseif inputtype == "hat" then
		setColor(50,50,50)
		gr.print(inputindex and ("Hat_"..(inputindex-1).."_"..hatdirection), x + 55, y + 16)
		if current_joy:getHat(inputindex) == hatdirection then
			setColor(100,100,100)
		else
			setColor(255,255,255)
		end
	else
		setColor(50,50,50)
		gr.print("None", x + 55, y + 16)
		setColor(255,255,255)
	end
	gr.draw(img, x, y, 0, rx, ry)
end

function drawSerial(x,y)
	gr.rectangle("line",x,y, 400, 60)

	local axis_count=6
	gr.print("Serial: "..serial_port, x, y)
end

function drawPPMSet(px,py, i)
	-- print(px,py)
	if ppm_set[i] and ppm_set[i].reverse then
		setColor(255,0,0)
		gr.rectangle("fill", px, py, 30, 18)
	end
	setColor(255,255,255)
	love.graphics.setFont(min_font)
	gr.print("Set", px + 5, py + 1)
	love.graphics.setFont(main_font)
	gr.rectangle("line", px, py, 30, 18)
	setColor(255,255,255)
end

function drawSerialStart(px,py)
	-- print(px,py)
	if serial_start then
		setColor(0,255,0)
	else
		setColor(255,0,0)
	end
	gr.rectangle("fill", px, py, 30, 18)
	setColor(255,255,255)
	love.graphics.setFont(min_font)
	gr.print(serial_start and "Stop" or "Start", px, py + 1)
	love.graphics.setFont(main_font)
	gr.rectangle("line", px, py, 30, 18)
	setColor(255,255,255)
end

function drawSerialSet(px,py)
	setColor(255,255,255)
	love.graphics.setFont(min_font)
	gr.print(" Set", px, py + 1)
	love.graphics.setFont(main_font)
	gr.rectangle("line", px, py, 30, 18)
	setColor(255,255,255)
end


function drawPPM(x, y)
	gr.rectangle("line",x,y, 400, 250)

	local axis_count=6
	gr.print("PPM:", x, y)

	for i=1, axis_count do

		local value = (ppm[i]-1500)/500

		local px = x + math.floor((i-1)/10) * 100 + 15
		local py = i * 35 + y - math.floor((i-1)/10) * 200 + 10

		setColor(255,255,255)
		gr.print((i-1)..":", px - main_font:getWidth(""..(i-1)..":"), py)

		setColor((value*255), 255 - math.abs(value*255), -(value*255))
		gr.rectangle("fill", px + 35 + 100, py, (value*250/2), 18)

		setColor(255,255,255)
		local val = math.floor(ppm[i])
		love.graphics.setFont(min_font)
		gr.print(val, px + 150 - min_font:getWidth(val), py + 1)
		love.graphics.setFont(main_font)
		gr.rectangle("line", px + 10, py, 250, 18)

		drawPPMSet(px + 270, py, i)
		love.graphics.setFont(min_font)
		if ppm_set[i] then
			gr.print((ppm_set[i].joy-1)..": "..ppm_set[i].type..": "..(ppm_set[i].value-1)..(ppm_set[i].type=="hat" and (" : "..ppm_set[i].dir) or ""), px + 305, py-1)
		else
			gr.print("not set", px + 305, py-1)
		end
		love.graphics.setFont(main_font)
	end
end

function drawAxis(x, y, j)
	j = j and j or current_joy
	gr.rectangle("line",x,y, 400, 250)

	local axis_count=j:getAxisCount()
	if axis_count == 0 then
		gr.print("Axis: No axes", x, y)
	else
		gr.print("Axis: "..axis_count, x, y)

		for i=1, axis_count do

			local px = x + math.floor((i-1)/10) * 100 + 15
			local py = i * 20 + y - math.floor((i-1)/10) * 200 + 10

			setColor(255,255,255)
			gr.print((i-1)..":", px - main_font:getWidth(""..(i-1)..":"), py)

			setColor((j:getAxis(i)*255), 255 - math.abs(j:getAxis(i)*255), -(j:getAxis(i)*255))
			gr.rectangle("fill", px + 35, py, (j:getAxis(i)*25), 18)

			setColor(255,255,255)
			local val = math.floor(j:getAxis(i) * 100).."%"
			love.graphics.setFont(min_font)
			gr.print(val, px + 59 - min_font:getWidth(val), py + 1)
			love.graphics.setFont(main_font)
			gr.rectangle("line", px + 10, py, 50, 18)
		end
	end
end

function drawButton(x, y, j)
	j = j and j or current_joy
	gr.setLineWidth(1)

	gr.rectangle("line",x,y, 400, 150)

	local button_count = j:getButtonCount()

	if button_count == 0 then
		gr.print("Button: No button", x, y)
	else
		gr.print("Button: "..button_count, x, y)
	end

	for i=1,button_count do
		local isDown = j:isDown(i)

		local px = x + (i-1) * 28 - math.floor((i-1)/10) * 280 + 14
		local py = y + math.floor((i-1)/10) * 28 + 12 + 25

		if isDown then
			setColor(255,0,0)
		else
			setColor(100,100,100)
		end
		gr.circle("fill", px, py + 4, 12)

		setColor(255,255,255)

		gr.circle("line", px, py + 4, 12)
		gr.print(i-1, px - main_font:getWidth(""..i-1)/2, py - 5)
	end
end

function drawHat(x, y, j)
	j = j and j or current_joy
	gr.setLineWidth(1)
	gr.rectangle("line",x,y, 400, 70)


	local hat_count = j:getHatCount()

	if hat_count == 0 then
		gr.print("Hat: No Hat", x, y)
	else
		gr.print("Hat: "..hat_count, x, y)
	end

	for i=1, hat_count do
		local d = j:getHat(i)

		local px = x + (i-1) * 50 - math.floor((i-1)/10) * 50 * 10
		local py = y + math.floor((i-1)/10) * 50 + 20

		gr.draw(gamepadText.Dpad, px, py, 0, 0.5)
		gr.setBlendMode("lighten","premultiplied")
		if d=="d" or d=="ld" or d=="rd" then gr.draw(gamepadText.dpdown, px, py, 0, 0.5) end
		if d=="u" or d=="lu" or d=="ru" then gr.draw(gamepadText.dpup, px, py, 0, 0.5) end
		if d=="l" or d=="ld" or d=="lu" then gr.draw(gamepadText.dpleft, px, py, 0, 0.5) end
		if d=="r" or d=="rd" or d=="ru" then gr.draw(gamepadText.dpright, px, py, 0, 0.5) end
		gr.setBlendMode("alpha")
		local lx, ly = gamepadText.Dpad:getWidth()/2, gamepadText.Dpad:getHeight()/2
		gr.print(i-1, px + lx/2 - main_font:getWidth(""..i-1)/2, py + ly/2 - main_font:getHeight(""..i-1)/2)

	end
end

function drawInfo(x, y, j)
	j = j and j or current_joy
	gr.rectangle("line",x,y, 400, 60)
	gr.print("Name: "..j:getName(), x, y)
	gr.print("GUID: "..j:getGUID(), x, y + 20)
	gr.print("Vibration Supported: "..(j:isVibrationSupported() and "Yes" or "False"), x, y + 40)
end

function drawClickButton(x,y,text)
	setColor(255,255,255)
	love.graphics.setFont(min_font)
	gr.print(text, x + 5, y + 1)
	love.graphics.setFont(main_font)
	gr.rectangle("line", x, y, 30, 18)
	setColor(255,255,255)
end

function drawOrderSet(x, y, j)
	j = j and j or current_joy
	gr.setLineWidth(1)
	gr.rectangle("line",x,y, 400, 70)

	drawClickButton(x + 10,y+10," + ")
	drawClickButton(x + 60,y+10,"  -")
end

function drawJoyList(x, y)
	gr.rectangle("line", x, y, 500, 120)

	local i = 0
	for k, v in ipairs(joysticks) do
		if (v == current_joy) then
			setColor(255,255,255)
			gr.print(">", x + 5, y + (15 * i) + 25)
		else

		end
		gr.print(v:getName(), x + 15 + 10, y + (15 * i) + 25)
		-- gr.print(v:getGUID(), x + 350, y + (15 * i) + 25)
		i = i + 1
	end

	if i > 0 then
		gr.print("Gamepad: "..i, x, y)
	else
		gr.print("Gamepad: None", x, y)
	end
end

function love.textinput(t)
	if serial_modif then
		serial_port = serial_port..t
	end
end

function love.keypressed(key, scancode, isrepeat)

	if serial_port then
		if key == "backspace" then
			serial_port = serial_port:sub(1, -2)
		end
		if key == "return" then
			serial_modif = false
		end
	end

	if key=="escape" then
		if modif then
			modif = false
		else
			love.event.quit()
		end
	end
	-- if key == "up" then
	-- 	local tab = {}
	-- 	local id = 0
	-- 	local i = 1
	-- 	for k,v in ipairs(joysticks) do
	-- 		table.insert(tab, v)
	-- 		if v == current_joy then id = i end
	-- 		i = i + 1
	-- 	end
	-- 	if tab[id - 1] then current_joy = tab[id - 1] end
	-- end
	-- if key == "down" then
	-- 	local tab = {}
	-- 	local id = 0
	-- 	local i = 1
	-- 	for k,v in ipairs(joysticks) do
	-- 		table.insert(tab, v)
	-- 		if v == current_joy then id = i end
	-- 		i = i + 1
	-- 	end
	-- 	if tab[id + 1] then current_joy = tab[id + 1] end
	-- end

	-- if key == "r" then
	-- 	modif = 'a'
	-- 	modif_type = 'button'
	-- 	-- love.joystick.loadGamepadMappings("test")
	-- 	local guid, name, tab = keymapToTab(current_joy:getGUID())
	-- 	-- keymapSetKey(guid, name, "leftx", "button", 1, nil)
	-- 	-- keymapSetKey(guid, name, "dpup", "hat", 0, 1)
	-- 	-- keymapSetKey(guid, name, "leftx", "axis", 0, nil)
	-- 	save = saveAxis(current_joy)
	--
	-- 	print(love.joystick.saveGamepadMappings())
	-- end

	-- if key == "r" then
	-- 	current_joy:setVibration( 0, 1, 1)
	-- end
	--
	-- if key == "t" then
	-- 	current_joy:setVibration( 1, 0, 1 )
	-- end

	-- if key == 'i' then
	-- 	print(love.joystick.saveGamepadMappings())
	-- end

end


function saveAxis()
	t = {}
	for k,v in ipairs(joysticks) do
		t[k] = {}
		for i=1, v:getAxisCount() do
			t[k][i] = v:getAxis(i)
		end
	end
	return t
end

function findModifAxis()
	local abs = math.abs
	for k,v in ipairs(joysticks) do
		for i=1, v:getAxisCount() do
			if abs(save[k][i] - v:getAxis(i)) > 0.30 then
				return k,i
			end
		end
	end
	return nil
end

function love.joystickpressed( joystick, button )
	if modif then
		if not ppm_set[modif] then ppm_set[modif] = {} end
		ppm_set[modif].type = "button"
		ppm_set[modif].value = button
		ppm_set[modif].joy = getJoyIndex(joystick)
		modif = false
	end
end

function love.joystickaxis( joystick, axis, value )
	if modif then
		local j,i = findModifAxis(joystick, save)
		if j then
			if not ppm_set[modif] then ppm_set[modif] = {} end
			ppm_set[modif].type = "axis"
			ppm_set[modif].value = i
			ppm_set[modif].joy = j
			modif = false
		end
	end
end

function love.joystickhat( joystick, hat, direction )
	if modif then
		if not ppm_set[modif] then ppm_set[modif] = {} end
		ppm_set[modif].type = "hat"
		ppm_set[modif].value = hat
		ppm_set[modif].joy = getJoyIndex(joystick)
		ppm_set[modif].dir = direction
		modif = false
	end
end

function love.mousepressed(x, y, button, isTouch)

	local px, py = 520, 400

	if not modif then
		ClicksetPPM(x,y, 285, 105, button, 1)
		ClicksetPPM(x,y, 285, 140, button, 2)
		ClicksetPPM(x,y, 285, 175, button, 3)
		ClicksetPPM(x,y, 285, 210, button, 4)
		ClicksetPPM(x,y, 285, 245, button, 5)
		ClicksetPPM(x,y, 285, 280, button, 6)

		for i=1, #joysticks do
			ClickOrderSet(x,y,(400*i)+10, 400 + 60 + 70 + 10, button, i, 1)
		end
		for i=1, #joysticks do
			ClickOrderSet(x,y,(400*i)+10 + 60, 400 + 60 + 70 + 10, button, i, -1)
		end

		if ClicksetPPM(x,y,300,10, nil) then
			if not serial_start then
				serial_start, err = sp.open(serial_port, 115200)
				if not serial_start then
					print("Can't open:", serial_port, err)
				else
					print("Open: "..serial_port)
				end
			end
		end
		if ClicksetPPM(x,y,250,10, nil) then
			serial_modif = true
		end
	end
end

function mouseSingleInput(mouseX, mouseY, x, y, key)
	if	mouseX >= x
		and mouseX <= x + 145
		and mouseY >= y
		and mouseY <= y + 50
	then
		print(key)
		modif = key
		modif_time = 0
		if isButton(key) then
			modif_type = "button"
		else
			modif_type = "axis"
			save = saveAxis()
		end
	end
end


function ClicksetPPM(mouseX, mouseY, x, y, button, value)
	if	mouseX >= x
		and mouseX <= x + 30
		and mouseY >= y
		and mouseY <= y + 18
	then
		if button == 1 then
			modif = value
			modif_time = 0
			save = saveAxis()
		elseif button == 2 and ppm_set[value] then
			ppm_set[value].reverse = not ppm_set[value].reverse
		end
		return true
	end
end

function ClickOrderSet(mouseX, mouseY, x, y, button, value, move)
	if	mouseX >= x
		and mouseX <= x + 30
		and mouseY >= y
		and mouseY <= y + 18
	then
		if button == 1 then
			if move == 1 and value > 1 then
				local tmp = joysticks[value-1]
				joysticks[value-1] = joysticks[value]
				joysticks[value] = tmp
			elseif move == -1 and value < #joysticks then
				local tmp = joysticks[value+1]
				joysticks[value+1] = joysticks[value]
				joysticks[value] = tmp
			end
		elseif button == 2 and ppm_set[value] then
			-- ppm_set[value].reverse = not ppm_set[value].reverse
		end
		return true
	end
end

function love.quit()
	local tmp = json.encode({
		ppm_set = ppm_set,
		serial_port = serial_port
	})
	print(tmp)
	love.filesystem.write("save.json", tmp)
end
