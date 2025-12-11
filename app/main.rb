require 'app/wrapped_sprite'
require 'app/user_interface'
require 'app/game'
require 'app/flea'

include UserInterface

# STATES
def setup args
  puts "\n\n*** SETUP ***\n\n"
  
  # TERRAIN
  # args.state.game.terrain ||= init_landscape
  
  # GLOBALS
  args.state.global.terrain.w ||= 1600
  args.state.global.terrain.h ||= 720
  args.state.global.dampening ||= 0.4
  args.state.global.line_mapping = { :x2 => :x, :y2 => :y }
  
  # CAMERA
  args.state.camera.offset_x ||= 0
  
  # TEMP PLAYER
  # This should probably move
  args.state.ball.name = "flea"
  args.state.ball.w = 10
  args.state.ball.h = 10
  args.state.ball.x ||= rand() * args.state.global.terrain.w
  args.state.ball.y ||= 600
  args.state.ball.next_x ||= args.state.ball.x
  args.state.ball.next_y ||= args.state.ball.y
  args.state.ball.speed.y ||= 1
  args.state.ball.speed.x ||= -1
  args.state.ball.bounciness ||= 0.9
  args.state.ball.is_grounded ||= false
  args.state.ball.color = { r: 196, g: 16, b: 64 }
  args.state.ball.type = :solid
  args.state.ball.screen_x = 0
  puts "screen_x: #{args.state.ball}"
  
  args.state.player.aim.angle ||= 90
  args.state.player.aim.power ||= 50
  
  args.state.game.projectiles ||= []
  
  args.state.game.projectiles << init_ball.tap do |p|
    p.name = "assbutt"
    p.x = 1147
  end
  args.state.game.projectiles << init_ball.tap do |p|
    p.name = "crustydick"
    p.w = 10
    p.h = 10
    p.x = 402
  end

  
  # Put everything before this, because the state will trigger
  args.state.app.state = :splash
  args.state.game.set_playstate :review
end

def splash args
  # puts "\n\n*** SPLASH ***\n\n"
  
  # INPUT
  
  # Move to playing screen on keyboard or mouse input
  if args.inputs.keyboard.active || args.inputs.mouse.up
    args.state.app.state = :playing
  end
  
  # RENDERING
  args.outputs.labels << [
    640,                   # X
    360,                   # Y
    "BATTLE_FLEAS",         # TEXT
    2,                     # SIZE_ENUM
    1,                     # ALIGNMENT_ENUM
    0,                     # RED
    0,                     # GREEN
    0,                     # BLUE
    255,                   # ALPHA
    "fonts/coolfont.ttf"   # FONT
  ]
end

def playing args
  
  # INPUT
  
  # View controls
  if args.inputs.mouse.buttons.left.held
    args.state.camera.offset_x += args.inputs.mouse.relative_x
  end
  
  # Player controls
  if args.state.game.playstate == :interact
    if args.inputs.keyboard.t
      args.state.ball.x = rand() * args.state.global.terrain.w
      args.state.ball.y = 600
      args.state.ball.next_x = args.state.ball.x
      args.state.ball.next_y = args.state.ball.y
      args.state.ball.speed.x = 0
      args.state.ball.speed.y = 0
    end
    if args.inputs.keyboard.space && args.state.ball.is_grounded
      x_offset = Math.cos(args.state.player.aim.angle * Math::PI / 180)
      y_offset = Math.sin(args.state.player.aim.angle * Math::PI / 180)
      relative_power = args.state.player.aim.power * 0.1
      args.state.ball.speed.x = x_offset * relative_power
      args.state.ball.speed.y = y_offset * relative_power
      
      args.state.game.set_playstate :review
    end
    
    # Aiming
    args.state.player.aim.angle -= args.inputs.left_right_directional
    args.outputs.debug.watch args.state.player.aim.angle.round
    args.state.player.aim.power += args.inputs.up_down_directional
    args.state.player.aim.power = args.state.player.aim.power.clamp(0, 100)
    args.outputs.debug.watch "Power: #{args.state.player.aim.power}"
    
    # Firing
    if args.inputs.keyboard.enter
      puts "FIRE!"
      # spawn a new projectile
      muzzle_x = (args.state.ball.x + args.state.game.player.aim.x * 20).round
      muzzle_y = (args.state.ball.y + args.state.game.player.aim.y * 20).round + 5
      
      # Spawn a new ball
      args.state.game.projectiles << init_ball.tap do |b|
        b.x = muzzle_x
        b.y = muzzle_y
        speed = { x: args.state.game.player.aim.x * args.state.player.aim.power * 0.1, y: args.state.game.player.aim.y * args.state.player.aim.power * 0.1 }
      end
      # Switch states
      # This doesn't stick because the 'ball' flea overrides the grounded state
      args.state.ball.grounded_start = nil
      args.state.game.set_playstate :review
    end
  end
  
  # CALCULATIONS
  calc_projectiles args
  # Remove inactive projectiles
  args.state.game.projectiles.reject! { |p| p.active == false }
  
  # TEST DB
  if args.state.game.playstate == :interact
    if args.state.db.test_result[:complete] && args.state.db.test_result.data.count > 0
      action = args.state.db.test_result.data.first
      puts "action: #{action}"
      
      case action[:action_type] # we have to use this style
      when "JUMP"
        puts "JUMP!"
        args.state.player.aim.angle = action[:angle]
        args.state.player.aim.power = action[:power]
        player_jump(args.state.player, args)
        action.active = false
      when "FIRE"
        puts "FIRE!"
        args.state.player.aim.angle = action[:angle]
        args.state.player.aim.power = action[:power]
        
        action.active = false
      end
      
      args.state.db.test_result.data.reject! {|action| action.active == false}
    end
  end
  
  
  # MOVEMENT
  if args.state.game.playstate == :review
    calc_projectile(args.state.ball, args)
  end
  
  # Aiming
  aim_y = Math.sin(args.state.player.aim.angle * Math::PI / 180)
  aim_x = Math.cos(args.state.player.aim.angle * Math::PI / 180)
  args.state.game.player.aim.x = aim_x
  args.state.game.player.aim.y = aim_y
  args.outputs.debug << "angle: #{aim_x}, #{aim_y}"
  
  # Screen position
  # Is this duplicated?
  args.state.ball.screen_x = (args.state.camera.offset_x + args.state.ball.x) % args.state.global.terrain.w
  
  # Playstate
  # if args.state.ball.grounded_start && Kernel.tick_count - args.state.ball.grounded_start > 40
  #   args.state.game.playstate = :interact
  #   args.state.ball.grounded_start = nil
  # end
  
  # RENDERING
  args.outputs[:scene].w = args.state.global.terrain.w
  args.outputs[:scene].h = args.state.global.terrain.h
  
  # Render terrain
  args.outputs[:scene].lines << args.state.game.terrain
  
  # Render flea
  # puts "BALL: #{args.state.ball}"
  args.outputs[:scene].sprites << render_wrapped(args.state.ball, args)
  
  args.state.game.projectiles.each do |p|
    args.outputs[:scene].sprites << render_wrapped(p, args)
  end
  
  # Render aiming
  x1 = args.state.ball.x
  x2 = (args.state.ball.x + aim_x * 20).round
  args.outputs.debug << "x1: #{x1}"
  args.outputs.debug << "x2: #{x2}"
  args.outputs[:scene].lines << {
    x:  args.state.ball.x,
    y:  args.state.ball.y + 5,
    x2: (args.state.ball.x + aim_x * 20).round,
    y2: (args.state.ball.y + aim_y * 20).round + 5,
    r:  0,
    g:  0,
    b:  0,
    a:  255,
    blendmode_enum: 1
  }
  args.outputs[:scene].lines << {
    x:  args.state.ball.x - 1600,
    y:  args.state.ball.y + 5,
    x2: case
          when x2 < 0 && x1 > 0 then 1600 - x2
          when x2 > 1600 then x2 - 1600
          else x2
        end,
    y2: (args.state.ball.y + aim_y * 20).round + 5,
    r:  0,
    g:  0,
    b:  0,
    a:  255,
    blendmode_enum: 1
  }
  
  # RENDER SCENE
  # Check for out of screen
  # percentage way
  if args.state.game.playstate == :review
    camera_offset_perc = (args.state.ball.screen_x - 640) / 640
    args.outputs.debug << "camera_offset_perc: #{camera_offset_perc}"
    args.state.camera.offset_x -= camera_offset_perc * 10
  end
  # edge way
  # if args.state.ball.position.screen_x < 120
  #   # shift right
  #   args.state.camera.offset_x += 1
  # elsif args.state.ball.position.screen_x > 1280 - 120
  #   # shift left
  #   args.state.camera.offset_x -= 1
  # end
    
  args.outputs.sprites << { x: args.state.camera.offset_x % args.state.global.terrain.w,
                            y: 0,
                            w: args.state.global.terrain.w,
                            h: 720,
                            path: :scene }
  args.outputs.sprites << { x: (args.state.camera.offset_x % args.state.global.terrain.w) - args.state.global.terrain.w,
                            y: 0,
                            w: args.state.global.terrain.w,
                            h: 720,
                            path: :scene }
                            
  # Render power bar
  args.outputs.sprites << UserInterface.powerbar(args.state.player.aim.power)
  
  args.outputs.debug << "grounded_start: #{args.state.ball.grounded_start}"
  args.outputs.debug << "playstate: #{args.state.game.playstate}"
  args.outputs.debug << "screen position: #{args.state.ball.screen_x}"
  args.outputs.debug << "ball y: #{args.state.ball.y}"
  args.outputs.debug << "current height: #{args.state.game.terrain[args.state.ball.x][:y2]}"
end

def calc_projectiles args
  projectiles = args.state.game.projectiles.reject {|p| p.is_grounded || !p.active }
 
  if projectiles.empty?
    args.state.game.set_playstate :interact
  else
    projectiles.each {|p| calc_projectile(p, args) }
  end

end

# TICK
def tick args
  $game ||= Game.new
  $game.args = args
  
  args.state.app.state ||= :setup
  
  test_database args
  
  # MAIN STATE SWITCH
  case args.state.app.state
  when :setup then setup args
  when :splash then splash args
  when :playing then playing args
  else
    # We shouldn't ever get here
    puts "\n\n*** BAD STATE ***\n\n"
  end
end



def render_wrapped(sp, args)
  # puts sp
  # Check variables
  puts "Invalid size" if sp.w.nil? || sp.h.nil?
  puts "Invalid position" if sp.x.nil? || sp.y.nil?
  puts "Invalid color" if sp.color.nil?
  
  output = []
  output << {
    x: sp.x,
    anchor_x: 0.5,
    y: sp.y,
    w: sp.w,
    h: sp.h,
    path: sp.type,
    r: sp.color.r,
    g: sp.color.g,
    b: sp.color.b,
    a: 255
  }
  if sp.x < sp.w.half
    output << {
      x: sp.x + args.state.global.terrain.w,
      anchor_x: 0.5,
      y: sp.y,
      w: sp.w,
      h: sp.h,
      path: sp.type,
      r: sp.color.r,
      g: sp.color.g,
      b: sp.color.b,
      a: 255
    }
  end
  if sp.x > (args.state.global.terrain.w - sp.w.half)
    output << {
      x: sp.x - args.state.global.terrain.w,
      anchor_x: 0.5,
      y: sp.y,
      w: sp.w,
      h: sp.h,
      path: sp.type,
      r: sp.color.r,
      g: sp.color.g,
      b: sp.color.b,
      a: 255
    }
  end
  output
end



def jump flea
  flea.speed.x = Math.cos(flea.aim.angle * Math::PI / 180) * flea.aim.power * 0.1
  flea.speed.y = Math.sin(flea.aim.angle * Math::PI / 180) * flea.aim.power * 0.1
end

def test_database args
  args.state.db.headers ||= [
    'apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtldGN4ZWlkZmdlam9qemVmemtkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MDg4MzcsImV4cCI6MjA3MTI4NDgzN30.eVMluWN13MhFFOHv_V0kzwrBpXkfp5sUV97kbad1eYk',
    'authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtldGN4ZWlkZmdlam9qemVmemtkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MDg4MzcsImV4cCI6MjA3MTI4NDgzN30.eVMluWN13MhFFOHv_V0kzwrBpXkfp5sUV97kbad1eYk'
  ]
  url = "https://ketcxeidfgejojzefzkd.supabase.co/rest/v1/action?select=*"
  
  args.state.db.test_result ||= args.gtk.http_get(url, args.state.db.headers)
  
  if args.state.db.test_result && args.state.db.test_result[:complete] && !args.state.db.printed
    if args.state.db.test_result[:http_response_code] == 200
      puts "The response was successful. The body is:"
      puts args.state.db.test_result[:response_data]
      args.state.db.test_result.response_tick = Kernel.tick_count
      args.state.db.test_result.data = args.gtk.parse_json(args.state.db.test_result[:response_data])
      args.state.db.test_result.data.each do |d|
        d.transform_keys!(&:to_sym)
      end
    else
      puts "The response failed. Status code:"
      puts args.state.db.test_result[:http_response_code]
    end
    # set a flag denoting that the response has been printed
    args.state.db.printed = true
  end
end

def init_ball
  {
    active: true,
    name: 'pants',
    w: 7,
    h: 7,
    x: 400,
    y: 400,
    next_x: 0,
    next_y: 0,
    screen_x: 400,
    speed: { x: 1, y: 4 },
    bounciness: 0.5,
    is_grounded: false,
    grounded_start: nil,
    explodes: true,
    color: { r: 0, g: 128, b: 64 }
  }
end

def player_jump(player, args)
  puts "player_jump"
  args.state.game.set_playstate :review
  
  args.state.ball.speed.x = Math.cos(args.state.player.aim.angle * Math::PI / 180) * args.state.player.aim.power * 0.1
  args.state.ball.speed.y = Math.sin(args.state.player.aim.angle * Math::PI / 180) * args.state.player.aim.power * 0.1
end

def player_fire(player, args)
  puts "player_fire"
  args.state.game.set_playstate :review
  
  args.state.game.player.aim.x = Math.cos(args.state.player.aim.angle * Math::PI / 180)
  args.state.game.player.aim.y = Math.sin(args.state.player.aim.angle * Math::PI / 180)
  
  muzzle_x = (args.state.ball.x + args.state.game.player.aim.x * 20).round
  muzzle_y = (args.state.ball.y + args.state.game.player.aim.y * 20).round + 5
  
  # Spawn a new ball
  args.state.game.projectiles << init_ball.tap do |b|
    b.x = muzzle_x
    b.y = muzzle_y
    b.speed = { x: args.state.game.player.aim.x * args.state.player.aim.power * 0.1, y: args.state.game.player.aim.y * args.state.player.aim.power * 0.1 }
  end
end