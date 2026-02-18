require 'app/wrapped_sprite'
require 'app/user_interface'
require 'app/setup'
require 'app/game'
require 'app/flea'
require 'app/landscape'
require 'app/terrain'
require 'app/multiplayer'
require 'app/projectile_types'

include Setup
include Landscape
include Game
include Flea
include UserInterface
include Terrain
include Multiplayer
include ProjectileTypes

# HELPERS

def current_flea(args)
  args.state.game.fleas[args.state.turn.current_index]
end

def advance_turn(args)
  num = args.state.game.num_players
  start_index = args.state.turn.current_index

  # Advance to next alive flea, skipping dead ones
  loop do
    args.state.turn.current_index = (args.state.turn.current_index + 1) % num
    if args.state.turn.current_index == 0
      args.state.turn.number += 1
    end

    flea = current_flea(args)
    break if flea.alive

    # If we've cycled all the way around, no one is alive
    if args.state.turn.current_index == start_index
      break
    end
  end

  args.state.turn.action = nil

  flea = current_flea(args)
  flea.grounded_start = nil if flea.alive
end

# STATES
def setup args
  puts "\n\n*** SETUP ***\n\n"

  setup_globals args
  setup_camera args
  setup_multiplayer args
  setup_game args
  setup_fleas args
  setup_pickups args
  setup_turns args

  # Place fleas on terrain surface
  args.state.game.fleas.each_value do |flea|
    terrain_height = terrain_top_at(args.state.game.terrain_segments, flea.x, args.state.global.terrain.w)
    flea.y = terrain_height
    flea.is_grounded = true
  end

  # Put everything before this, because the state will trigger
  args.state.app.state = :splash
  args.state.game.playstate = :interact
end

def splash args
  args.state.menu.menu_selection ||= 0
  args.state.menu.mode ||= :menu  # :menu, :creating, :waiting, :joining, :error

  case args.state.menu.mode
  when :menu
    # Navigate menu
    if args.inputs.keyboard.key_down.down
      args.state.menu.menu_selection = (args.state.menu.menu_selection + 1) % 3
    end
    if args.inputs.keyboard.key_down.up
      args.state.menu.menu_selection = (args.state.menu.menu_selection - 1) % 3
    end

    if args.inputs.keyboard.key_down.enter || args.inputs.keyboard.key_down.space
      case args.state.menu.menu_selection
      when 0  # Local Game
        args.state.mp.enabled = false
        args.state.app.state = :playing
      when 1  # New Online Game
        args.state.menu.player_count_selection = 2
        args.state.menu.mode = :pick_players
      when 2  # Join Online Game
        args.state.mp.enabled = true
        args.state.mp.join_code_input = ""
        args.state.menu.mode = :joining
      end
    end

    # Render menu
    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }

    menu_items = ["Local Game", "New Online Game", "Join Online Game"]
    menu_items.each_with_index do |item, i|
      selected = (i == args.state.menu.menu_selection)
      prefix = selected ? "> " : "  "
      args.outputs.labels << {
        x: 640, y: 380 - (i * 40), text: "#{prefix}#{item}",
        size_enum: 1, alignment_enum: 1,
        r: selected ? 255 : 150, g: selected ? 255 : 150, b: selected ? 0 : 150, a: 255
      }
    end

  when :pick_players
    if args.inputs.keyboard.key_down.escape
      args.state.menu.mode = :menu
      return
    end

    if args.inputs.keyboard.key_down.left
      args.state.menu.player_count_selection = [2, args.state.menu.player_count_selection - 1].max
    end
    if args.inputs.keyboard.key_down.right
      args.state.menu.player_count_selection = [6, args.state.menu.player_count_selection + 1].min
    end

    if args.inputs.keyboard.key_down.enter || args.inputs.keyboard.key_down.space
      args.state.mp.enabled = true
      mp_create_game(args, args.state.menu.player_count_selection)
      args.state.menu.mode = :creating
      return
    end

    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }
    args.outputs.labels << {
      x: 640, y: 400, text: "Number of Players:",
      size_enum: 1, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255
    }
    args.outputs.labels << {
      x: 640, y: 360, text: "< #{args.state.menu.player_count_selection} >",
      size_enum: 3, alignment_enum: 1,
      r: 255, g: 255, b: 0, a: 255
    }
    args.outputs.labels << {
      x: 640, y: 310, text: "LEFT/RIGHT to change, ENTER to create, ESC to cancel",
      size_enum: 0, alignment_enum: 1,
      r: 150, g: 150, b: 150, a: 255
    }

  when :creating
    # Waiting for game creation + opponents
    mp_tick(args)

    if args.state.mp.mp_state == :ready
      # Opponent joined, regenerate terrain with seed and start
      setup_game args
      setup_fleas args
      setup_pickups args
      setup_turns args
      args.state.game.fleas.each_value do |flea|
        terrain_height = terrain_top_at(args.state.game.terrain_segments, flea.x, args.state.global.terrain.w)
        flea.y = terrain_height
        flea.is_grounded = true
      end
      args.state.app.state = :playing
      args.state.game.playstate = :interact
      return
    end

    if args.state.mp.mp_state == :error
      args.state.menu.mode = :error
      return
    end

    if args.inputs.keyboard.key_down.escape
      args.state.mp.enabled = false
      args.state.mp.mp_state = :idle
      args.state.menu.mode = :menu
      return
    end

    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }
    args.outputs.labels << UserInterface.join_code_display(args.state.mp.join_code)
    current = args.state.mp.current_player_count || 1
    target = args.state.mp.target_players || 2
    args.outputs.labels << UserInterface.waiting_indicator
    args.outputs.labels << {
      x: 640, y: 350, text: "Players: #{current} / #{target}",
      size_enum: 1, alignment_enum: 1,
      r: 200, g: 200, b: 200, a: 255
    }
    args.outputs.labels << {
      x: 640, y: 300, text: "Press ESC to cancel",
      size_enum: 0, alignment_enum: 1,
      r: 150, g: 150, b: 150, a: 255
    }

  when :joining
    # Text input for join code
    if args.inputs.keyboard.key_down.escape
      args.state.menu.mode = :menu
      return
    end

    # Number key input (0-9 keys)
    %w[zero one two three four five six seven eight nine].each_with_index do |name, digit|
      if args.inputs.keyboard.key_down.send(name.to_sym)
        if args.state.mp.join_code_input.length < 6
          args.state.mp.join_code_input += digit.to_s
        end
      end
    end

    # Backspace
    if args.inputs.keyboard.key_down.backspace
      if args.state.mp.join_code_input.length > 0
        args.state.mp.join_code_input = args.state.mp.join_code_input[0..-2]
      end
    end

    # Submit
    if args.inputs.keyboard.key_down.enter && args.state.mp.join_code_input.length == 6
      mp_join_game(args, args.state.mp.join_code_input)
      args.state.menu.mode = :joining_wait
    end

    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }
    args.outputs.labels << UserInterface.join_code_input_display(args.state.mp.join_code_input)

  when :joining_wait
    mp_tick(args)

    if args.state.mp.mp_state == :ready
      # Joined successfully, regenerate terrain with seed and start
      setup_game args
      setup_fleas args
      setup_pickups args
      setup_turns args
      args.state.game.fleas.each_value do |flea|
        terrain_height = terrain_top_at(args.state.game.terrain_segments, flea.x, args.state.global.terrain.w)
        flea.y = terrain_height
        flea.is_grounded = true
      end
      args.state.app.state = :playing
      args.state.game.playstate = :interact
      return
    end

    if args.state.mp.mp_state == :error
      args.state.menu.mode = :error
      return
    end

    if args.inputs.keyboard.key_down.escape
      args.state.mp.enabled = false
      args.state.mp.mp_state = :idle
      args.state.menu.mode = :menu
      return
    end

    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }
    if args.state.mp.mp_state == :waiting_for_opponent
      current = args.state.mp.current_player_count || 1
      target = args.state.mp.target_players || 2
      args.outputs.labels << UserInterface.waiting_indicator
      args.outputs.labels << {
        x: 640, y: 350, text: "Players: #{current} / #{target}",
        size_enum: 1, alignment_enum: 1,
        r: 200, g: 200, b: 200, a: 255
      }
    else
      args.outputs.labels << {
        x: 640, y: 400, text: "Joining game...",
        size_enum: 1, alignment_enum: 1,
        r: 255, g: 255, b: 255, a: 255
      }
    end

  when :error
    if args.inputs.keyboard.key_down.escape
      args.state.mp.enabled = false
      args.state.mp.mp_state = :idle
      args.state.mp.error_message = nil
      args.state.menu.mode = :menu
    end

    args.outputs.labels << {
      x: 640, y: 480, text: "BATTLE_FLEAS",
      size_enum: 4, alignment_enum: 1,
      r: 255, g: 255, b: 255, a: 255,
      font: "fonts/coolfont.ttf"
    }
    args.outputs.labels << UserInterface.mp_error_display(args.state.mp.error_message || "Unknown error")
  end
end

def playing args
  flea = current_flea(args)

  # Multiplayer tick
  mp_tick(args) if args.state.mp.enabled

  # INPUT

  # View controls
  if args.inputs.mouse.buttons.left.held
    args.state.camera.offset_x += args.inputs.mouse.relative_x
  end

  # Player controls
  if args.state.game.playstate == :interact
    # In multiplayer, skip input when it's not our turn
    if args.state.mp.enabled && !is_local_turn?(args)
      # Start polling if not already
      if args.state.mp.mp_state == :idle || args.state.mp.mp_state == :ready
        mp_start_polling(args)
      end
    else
      # Debug: reset flea position
      if args.inputs.keyboard.t
        flea.x = rand() * args.state.global.terrain.w
        flea.y = 600
        flea.next_x = flea.x
        flea.next_y = flea.y
        flea.speed.x = 0
        flea.speed.y = 0
      end

      # Jump
      if args.inputs.keyboard.key_down.space && flea.is_grounded
        x_offset = Math.cos(flea.aim.angle * Math::PI / 180)
        y_offset = Math.sin(flea.aim.angle * Math::PI / 180)
        relative_power = flea.aim.power * 0.1
        flea.speed.x = x_offset * relative_power
        flea.speed.y = y_offset * relative_power
        flea.is_grounded = false
        flea.grounded_start = nil

        args.state.turn.action = :jump
        args.state.game.playstate = :review
      end

      # Weapon cycling
      if args.inputs.keyboard.key_down.tab
        weapons = available_weapons
        idx = weapons.index(flea.weapon) || 0
        flea.weapon = weapons[(idx + 1) % weapons.length]
      end

      # Aiming
      flea.aim.angle -= args.inputs.left_right_directional
      flea.aim.power += args.inputs.up_down_directional
      flea.aim.power = flea.aim.power.clamp(0, 100)

      # Firing
      if args.inputs.keyboard.key_down.enter
        aim_x = Math.cos(flea.aim.angle * Math::PI / 180)
        aim_y = Math.sin(flea.aim.angle * Math::PI / 180)

        muzzle_x = (flea.x + aim_x * 20).round
        muzzle_y = (flea.y + aim_y * 20).round + 5

        args.state.game.projectiles << init_projectile(flea.weapon).tap do |b|
          b.x = muzzle_x
          b.y = muzzle_y
          b.speed = { x: aim_x * flea.aim.power * 0.1, y: aim_y * flea.aim.power * 0.1 }
        end

        args.state.turn.action = :fire
        args.state.game.playstate = :review
      end
    end
  end

  # CALCULATIONS
  calc_projectiles args
  # Remove inactive projectiles
  args.state.game.projectiles.reject! { |p| p.active == false }

  # MOVEMENT
  if args.state.game.playstate == :review
    # If the action was a jump, run physics on the active flea
    if args.state.turn.action == :jump
      calc_projectile(flea, args)
    end

    # Run physics on any flea that lost ground (e.g. from explosion)
    args.state.game.fleas.each_value do |f|
      next unless f.alive
      next if f.is_grounded
      next if args.state.turn.action == :jump && f == flea  # already handled above
      calc_projectile(f, args)
    end

    # Check pick-up collection for all moving fleas
    args.state.game.fleas.each_value do |f|
      next unless f.alive
      next if f.is_grounded
      check_pickup_collection(f, args)
    end

    # Process falling terrain
    if args.state.game.terrain_falling
      process_falling_terrain(args)
    end

    # Rebuild terrain render cache when dirty
    if args.state.game.terrain_dirty
      args.state.game.terrain_lines = rebuild_terrain_lines(args.state.game.terrain_segments, args.state.global.terrain.w)
      args.state.game.terrain_dirty = false
    end

    # Check if everything has settled
    all_fleas_grounded = args.state.game.fleas.all? { |_k, f| !f.alive || f.is_grounded }
    flea_settled = (args.state.turn.action != :jump || flea.is_grounded) && all_fleas_grounded
    projectiles_settled = args.state.game.projectiles.all? { |p| p.is_grounded || !p.active }
    terrain_settled = !args.state.game.terrain_falling

    if flea_settled && projectiles_settled && terrain_settled
      if args.state.mp.enabled
        if is_local_turn?(args)
          # Upload once, then wait for confirmation
          if args.state.mp.mp_state != :uploading
            mp_upload_turn(args)
          end
          # Do nothing while uploading — advance_turn is called in handle_http_response
        else
          # Opponent's turn replay finished — snap to authoritative state
          if args.state.mp.mp_state == :replaying
            mp_apply_authoritative_state(args, args.state.mp.replay_data)
            args.state.game.terrain_lines = rebuild_terrain_lines(args.state.game.terrain_segments, args.state.global.terrain.w)
            args.state.mp.replay_data = nil
            args.state.mp.mp_state = :idle
            advance_turn(args)
            args.state.game.playstate = :interact
          end
        end
      else
        advance_turn(args)
        args.state.game.playstate = :interact
      end
    end
  end

  # Aiming calculations (for rendering aim line)
  aim_y = Math.sin(flea.aim.angle * Math::PI / 180)
  aim_x = Math.cos(flea.aim.angle * Math::PI / 180)

  # Screen position for active flea
  flea.screen_x = (args.state.camera.offset_x + flea.x) % args.state.global.terrain.w

  # RENDERING
  args.outputs[:scene].w = args.state.global.terrain.w
  args.outputs[:scene].h = args.state.global.terrain.h

  # Render terrain
  args.outputs[:scene].lines << args.state.game.terrain_lines

  # Render ALL alive fleas with health bars
  args.state.game.fleas.each_value do |f|
    next unless f.alive
    args.outputs[:scene].sprites << render_wrapped(f, args)

    # Health bar background
    args.outputs[:scene].sprites << {
      x: f.x - 8, y: f.y + 12, w: 16, h: 3,
      path: :solid, r: 60, g: 60, b: 60, a: 200
    }
    # Health bar fill
    health_pct = f.health / 100.0
    bar_r = ((1 - health_pct) * 255).to_i
    bar_g = (health_pct * 255).to_i
    args.outputs[:scene].sprites << {
      x: f.x - 8, y: f.y + 12, w: (16 * health_pct).round, h: 3,
      path: :solid, r: bar_r, g: bar_g, b: 0, a: 200
    }
  end

  # Render pick-ups
  args.state.game.pickups.each do |pickup|
    next unless pickup.active
    args.outputs[:scene].sprites << render_wrapped(pickup, args)
  end

  # Render projectiles
  args.state.game.projectiles.each do |p|
    args.outputs[:scene].sprites << render_wrapped(p, args)
  end

  # Render aiming line (only for active flea during :interact)
  if args.state.game.playstate == :interact
    args.outputs[:scene].lines << {
      x:  flea.x,
      y:  flea.y + 5,
      x2: (flea.x + aim_x * 20).round,
      y2: (flea.y + aim_y * 20).round + 5,
      r:  flea.color.r,
      g:  flea.color.g,
      b:  flea.color.b,
      a:  255,
      blendmode_enum: 1
    }
    # Wrapped copy of aim line
    args.outputs[:scene].lines << {
      x:  flea.x - 1600,
      y:  flea.y + 5,
      x2: (flea.x - 1600 + aim_x * 20).round,
      y2: (flea.y + aim_y * 20).round + 5,
      r:  flea.color.r,
      g:  flea.color.g,
      b:  flea.color.b,
      a:  255,
      blendmode_enum: 1
    }

    # Active flea highlight (circle behind active flea)
    args.outputs[:scene].sprites << {
      x: flea.x - 8,
      y: flea.y - 3,
      w: 16,
      h: 16,
      path: :solid,
      r: flea.color.r,
      g: flea.color.g,
      b: flea.color.b,
      a: 80
    }
  end

  # RENDER SCENE
  # Camera focus during review: follow projectile if in flight, otherwise follow active flea
  if args.state.game.playstate == :review
    active_projectile = args.state.game.projectiles.find { |p| p.active && !p.is_grounded }
    if active_projectile
      target_screen_x = active_projectile.screen_x
    else
      target_screen_x = flea.screen_x
    end
    camera_offset_perc = (target_screen_x - 640) / 640
    args.state.camera.offset_x -= camera_offset_perc * 10
  end

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
  args.outputs.sprites << UserInterface.powerbar(flea.aim.power)

  # Render weapon indicator
  args.outputs.labels << UserInterface.weapon_indicator(flea)

  # Render turn indicator
  args.outputs.labels << UserInterface.turn_indicator(flea, args.state.turn.number)

  # Multiplayer UI
  if args.state.mp.enabled
    if args.state.game.playstate == :interact && !is_local_turn?(args)
      args.outputs.labels << UserInterface.waiting_indicator
    end
    if args.state.mp.join_code
      args.outputs.labels << {
        x: 1240, y: 30, text: "Code: #{args.state.mp.join_code}",
        size_enum: -1, alignment_enum: 2,
        r: 150, g: 150, b: 150, a: 180
      }
    end
  end

  # Debug output
  args.outputs.debug << "playstate: #{args.state.game.playstate}"
  args.outputs.debug << "turn: #{args.state.turn.number}, player: #{flea.name}"
  args.outputs.debug << "angle: #{flea.aim.angle.round}, power: #{flea.aim.power}"
  args.outputs.debug << "grounded: #{flea.is_grounded}"
end

def calc_projectiles args
  projectiles = args.state.game.projectiles.select { |p| p.active && !p.is_grounded }

  if projectiles.empty?
    return
  end

  projectiles.each { |p| calc_projectile(p, args) }
end

def calc_projectile(p, args)
  return if p.is_grounded

  puts "Invalid position" if p.x.nil? || p.y.nil?

  segments = args.state.game.terrain_segments
  w = args.state.global.terrain.w

  # Apply gravity
  p.speed.y -= 0.1

  # Clamp speed to max
  max = args.state.global.max_speed
  p.speed.x = p.speed.x.clamp(-max, max)
  p.speed.y = p.speed.y.clamp(-max, max)

  # Predict position
  next_x = (p.x + p.speed.x) % w
  next_x_rounded = next_x.round % w
  next_y = (p.y + p.speed.y)

  # Look up projectile type properties (fleas have no projectile_type — skip all explosion checks)
  ptype = PROJECTILE_TYPES[p.projectile_type] if p.projectile_type
  explodes_on_flea = ptype ? ptype[:explodes_on_flea] : false
  explodes_on_terrain = ptype ? ptype[:explodes_on_terrain] : false

  # Check for flea collision (only for projectiles that explode on flea hit)
  if explodes_on_flea
    args.state.game.fleas.each_value do |flea|
      next unless flea.alive
      dx = ((next_x - flea.x + 800) % 1600) - 800
      dy = next_y - flea.y
      dist = Math.sqrt(dx * dx + dy * dy)
      hit_radius = (flea.w || 10) * 0.5 + (p.blast_radius || 20) * 0.5
      if dist < hit_radius
        projectile_on_impact(args, p, flea.x.round % w, flea.y.round)
        p.active = false
        return false
      end
    end
  end

  # Check for terrain collision using segment system
  hit = terrain_collision_segment(segments, p.x, p.y, next_x, next_y, w)
  if hit
    # Type explodes on terrain — trigger impact and deactivate
    if explodes_on_terrain
      projectile_on_impact(args, p, next_x_rounded, hit[:y])
      p.active = false
      return false
    end

    # Type does NOT explode on terrain but has an impact effect (e.g. repulsor)
    if ptype && (ptype[:impulse_radius] || ptype[:on_terrain_impact])
      projectile_on_impact(args, p, next_x_rounded, hit[:y])
      p.active = false
      return false
    end

    seg = hit[:segment]

    # Dampening
    p.speed.y *= p.bounciness * args.state.global.dampening * seg[:bounciness]
    p.speed.x *= p.bounciness * seg[:bounciness]

    # Bounce
    if hit[:surface] == :top
      next_y = seg[:top] * 2 - next_y
    else
      next_y = seg[:bottom] * 2 - next_y
    end
    p.speed.y = -p.speed.y

    # Slope deflection (only for top-surface collisions)
    if hit[:surface] == :top
      left_x = (next_x_rounded - 2) % w
      right_x = (next_x_rounded + 2) % w

      left_y = terrain_top_at(segments, left_x, w)
      right_y = terrain_top_at(segments, right_x, w)

      left_line = { x: left_x, y: left_y }
      right_line = { x: right_x, y: right_y }

      slope = left_line.angle_to(right_line)
      slope_sine = Math.sin(slope * Math::PI / 180)
      p.speed.x -= slope_sine
    end
  end

  # Check for grounding (near any terrain surface)
  surface_info = terrain_nearest_surface(segments, next_x, next_y, w)
  near_terrain = surface_info && surface_info[:dist] < 5

  if near_terrain && ((next_x - p.x).abs < 1) && ((next_y - p.y).abs < 2)
    if p.grounded_start.nil?
      p.grounded_start = Kernel.tick_count
    end
    if Kernel.tick_count - p.grounded_start > 20
      p.is_grounded = true
      p.grounded_start = nil
    end
  else
    p.grounded_start = nil
  end

  # Set the position for this frame
  p.x = next_x
  p.y = next_y

  # set the screen position
  p.screen_x = (args.state.camera.offset_x + p.x) % w
end

# TICK
def tick args
  args.state.app.state ||= :setup

  case args.state.app.state
  when :setup then setup args
  when :splash then splash args
  when :playing then playing args
  else
    puts "\n\n*** BAD STATE ***\n\n"
  end
end

def render_wrapped(sp, args)
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

def aim_to_x angle
  Math.cos(angle * Math::PI / 180)
end

def aim_to_y angle
  Math.sin(angle * Math::PI / 180)
end


def check_pickup_collection(flea, args)
  return unless flea.alive
  w = args.state.global.terrain.w

  args.state.game.pickups.each do |pickup|
    next unless pickup.active

    dx = ((flea.x - pickup.x + 800) % 1600) - 800
    dy = flea.y - pickup.y
    dist = Math.sqrt(dx * dx + dy * dy)

    if dist < 10
      pickup.active = false
      case pickup.pickup_type
      when :health
        flea.health = [flea.health + pickup.value, 100].min
      end
    end
  end
end

def explode_at(args, cx, cy, radius)
  segments = args.state.game.terrain_segments
  w = args.state.global.terrain.w

  affected = carve_circle(segments, cx, cy, radius, w)
  args.state.game.terrain_affected_cols ||= []
  args.state.game.terrain_affected_cols.concat(affected) if affected
  args.state.game.terrain_dirty = true
  args.state.game.terrain_falling = true

  # Damage and unground fleas near the blast
  args.state.game.fleas.each_value do |flea|
    next unless flea.alive

    dx = ((cx - flea.x + 800) % 1600) - 800
    dy = cy - flea.y
    dist = Math.sqrt(dx * dx + dy * dy)

    # Deal damage based on proximity (100 at center, 0 at edge of blast)
    if dist < radius
      damage = ((1 - dist / radius) * 100).round
      flea.health -= damage
      if flea.health <= 0
        flea.health = 0
        flea.alive = false
      end
    end

    # Unground fleas that lost terrain beneath them
    next unless flea.is_grounded
    surface = terrain_nearest_surface(segments, flea.x, flea.y, w)
    if surface.nil? || surface[:dist] > 5
      flea.is_grounded = false
      flea.grounded_start = nil
    end
  end
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
    args.state.db.printed = true
  end
end
