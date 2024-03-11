-- Test script to modify incoming apply Bezier curve mapping to incoming CC messages
-- Long press button 1: reset
-- Button 2: Show/hide values
-- Button 3: Enable/disable curve mapping
-- Encoder 1: Select values
-- Encodes 2/3: Modify selected values

musicutil = require ('musicutil')
util = require('util')

------------------------------------------------------------------------------------------------------------------------------

function init() 
  

  screen_dirty = true
  redraw_clock_id = clock.run(redraw_clock)
  
  input = 5
  output = 7
  cc_in = 0
  cc_out = 0
  enabled = true

  midi_device = {} -- container for connected midi devices
  midi_device_names = {}

	for i = 1,#midi.vports do -- query all ports
		midi_device[i] = midi.connect(i) -- connect each device
		table.insert( -- register its name:
		  midi_device_names, -- table to insert to
		  midi_device[i].name .. ' (' .. i .. ')'-- value to insert
		)
	  end
  
  connect()

end

-- Bezier curve control points
-- when plotted, x represents the input message and y is the curved response
local A = {x = 0, y = 0} -- A.x is set to 0, use A.y to set the minimum output
local B = {x = 0, y = 1.13} -- Shape the curve using points B and C
local C = {x = 0.77, y = 0.64}
local D = {x = 1, y = 1} -- D.x is set to 1, use D.y to set the maximum output


-- Cubic Bezier Curve Mapping
function transform(input, P0, P1, P2, P3)
  -- Normalize the input value of [0,127] to range [0, 1]
  local t = input / 127
  local output = {}
  output.input = input

  -- Bezier transform
  local u = 1 - t
  local tt = t * t
  local uu = u * u
  local uuu = uu * u
  local ttt = tt * t

  output.x = uuu * P0.x + 3 * uu * t * P1.x + 3 * u * tt * P2.x + ttt * P3.x
  output.y = uuu * P0.y + 3 * uu * t * P1.y + 3 * u * tt * P2.y + ttt * P3.y

  output.value = math.floor(output.y * 127) -- scaling and flooring output for use as CC message

  return output
end

-- Map 0 - 127 value to -96dB to 12dB
function map_to_db(input)
  local range_min, range_max = 0, 127
  local db_min, db_max = -96, 12
  return ((input - range_min) / (range_max - range_min)) * (db_max - db_min) + db_min
end

-- Use transform output to scale values to screen dimensions
function screenPoint(p)
  local scaledInvertedX = p.x * 127
  local scaledInvertedY = (1 - p.y) * (63 - 16) + 16 -- Invert y-coordinate after scaling
  return {x = scaledInvertedX, y = scaledInvertedY}
end


------------------------------------------------------------------------------------------------------------------------------

-- Manage midi devices
function connect()
  midi_in = midi_device[input]
  midi_out = midi_device[output]

  midi_in.event = function(d)
    local data = midi.to_msg(d)
    cc_in = data.val

    if data.type == 'cc' and enabled then  
      cc_out = transform(cc_in,A,B,C,D).value
      data.val = cc_out
    elseif data.type == 'cc' then
      cc_out = cc_in
    end
    
    midi_out:send( data )

    redraw()
  end

end

-- Functions for Norns Encoders
local cursor = 1
local actions = {}

actions[1] = function(d)
    A.y = util.clamp(A.y + (d/100), 0, 1 )
end

actions[2] = function(d)
    D.y = util.clamp(D.y + (d/100), 0, 1 )
    print(D.y)
end

actions[3] = function(d)
    B.x = util.clamp(B.x + (d/100), -5, 5 )
end

actions[4] = function(d)
    B.y = util.clamp(B.y + (d/100), -5, 5 )
end

actions[5] = function(d)
  C.x = util.clamp(C.x + (d/100), -5, 5 )
end

actions[6] = function(d)
  C.y = util.clamp(C.y + (d/100), -5, 5 )
end

actions[7] = function(d)
  input = util.clamp(input + d, 1, #midi_device )
  connect()
end

actions[8] = function(d)
  output = util.clamp(output + d, 1, #midi_device )
  connect()
end

function enc(e, d) --------------- enc() is automatically called by norns
  screen.ping()
  if not show then show = true end
  if e == 1 then
    cursor = util.clamp(cursor + d, 1, math.ceil(#actions / 2))
    print(cursor)
  end -- turn encoder 1
  
  if e == 2 then
    actions[cursor * 2 - 1](d)
  end -- turn encoder 3

  if e == 3 then
    actions[cursor * 2](d)
  end -- turn encoder 3

  redraw()
end

local show = true -- show/hide the data

function key(k, z) ------------------ key() is automatically called by norns
  screen.ping()
  if z == 0 then return end --------- do nothing when you release a key
  if k == 1 then r() end
  if k == 3 then enabled = not enabled end -- but press_down(2)
  if k == 2 then show = not show end -- and press_down(3)
  screen_dirty = true --------------- something changed
end

function redraw_clock() ----- a clock that draws space
  while true do ------------- "while true do" means "do this forever"
    clock.sleep(1/15) ------- pause for a fifteenth of a second (aka 15fps)
    if screen_dirty then ---- only if something changed
      redraw() -------------- redraw space
      screen_dirty = false -- and everything is clean again
    end
  end
end


function redraw() -------------- redraw() is automatically called by norns
  screen.clear() --------------- clear space
  screen.aa(1) ----------------- enable anti-aliasing
  screen.font_face(1) ---------- set the font face to "04B_03"
  screen.font_size(8) ---------- set the size to 8
  screen.level(15) ------------- max
  
  if show then
    
    
    if cursor == 1 then
      screen.move(0, 8)
      screen.text( 'A.y (min): ' .. A.y)
      screen.move(0, 16)
      screen.text( 'D.y (max): ' .. D.y)
      screen.fill()
    end

    if cursor == 2 then
      screen.move(0, 8)
      screen.text( 'B.x: ' .. B.x)
      screen.move(0, 16)
      screen.text( 'B.y: ' .. B.y)
      screen.fill()
    end

    if cursor == 3 then
      screen.move(0, 8)
      screen.text( 'C.x: ' .. C.x)
      screen.move(0, 16)
      screen.text( 'C.y: ' .. C.y)
      screen.fill()
    end
  end

  if cursor == 4 then
    screen.move(0, 8)
    screen.text( 'in: ' .. midi_device_names[input])
    screen.move(0, 16)
    screen.text( 'out: ' .. midi_device_names[output])
    screen.fill()
  end
  screen.move(127, 63)
  screen.text_right( 'cc: ' .. cc_in .. ' to ' .. cc_out )

  screen.fill() ---------------- fill the termini and message at once

  screen.level(2)
  
  
  local P0, P1, P2, P3 
  
  if enabled then
    P0, P1, P2, P3 = screenPoint(A), screenPoint(B), screenPoint(C), screenPoint(D)
  else
    P0, P1, P2, P3 = screenPoint({x=0,y=0}), screenPoint({x=0,y=0}), screenPoint({x=1,y=1}), screenPoint({x=1,y=1})
  end

  screen.move(P0.x,P0.y)
  screen.curve(P1.x,P1.y,P2.x,P2.y,P3.x,P3.y)
  screen.stroke()
  
  
  if cc_in >= 0 and cc_out >= 0 then
    if enabled then
        local curr = transform(cc_in,A,B,C,D)
        local plot = screenPoint(curr)


        screen.level(15)
        
        if plot.x < 50 then
          screen.move(plot.x + 3,plot.y+2)
          screen.text(math.floor(map_to_db(curr.value)) ..'dB')
        else
          screen.move(plot.x - 3,plot.y+ 2)
          screen.text_right(math.floor(map_to_db(curr.value))..'dB')
        end
        screen.move(plot.x,plot.y)
        screen.circle(plot.x,plot.y,2)
        local ap = screenPoint(A)
        local bp = screenPoint(B)
        local cp = screenPoint(C)
        local dp = screenPoint(D)
        screen.fill()

        screen.level(2)
       
        screen.circle(bp.x,bp.y,2)
        screen.fill()

        screen.line(ap.x,ap.y)
        screen.line(bp.x,bp.y)
        screen.stroke()
       
        screen.circle(cp.x,cp.y,2)
        screen.fill()
        
        screen.line(dp.x,dp.y)
        screen.line(cp.x,cp.y)
        screen.stroke()
    else
        local curr = transform(cc_in,{x=0,y=0},{x=0,y=0},{x=1,y=1},{x=1,y=1})
        local plot = screenPoint(curr)
        
        
        screen.level(15)
        
        if plot.x < 50 then
          screen.move(plot.x + 3,plot.y+2)
          screen.text(math.floor(map_to_db(curr.value)) .. 'dB')
        else
          screen.move(plot.x - 3,plot.y+ 2)
          screen.text_right(math.floor(map_to_db(curr.value)) .. 'dB')
        end
        screen.move(plot.x,plot.y)
        screen.circle(plot.x,plot.y,2)

        screen.fill()
    end
  end
  
  screen.level(15)
  screen.stroke()
  screen.update() -------------- update space
end


function unrequire(name) 
  package.loaded[name] = nil
  _G[name] = nil
end

function r() ----------------------------- execute r() in the repl to quickly rerun this script

  norns.script.load(norns.state.script) -- https://github.com/monome/norns/blob/main/lua/core/state.lua
end

function cleanup() --------------- cleanup() is automatically called on script close
  clock.cancel(redraw_clock_id) -- melt our clock vie the id we noted
end