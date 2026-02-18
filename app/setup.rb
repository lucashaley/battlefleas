module Setup
  def setup_app args
    args.state.app = {
      state: :none
    }
  end

  def setup_globals args
    puts "*** SETUP GLOBALS ***"
    args.state.global.terrain.w ||= 1600
    args.state.global.terrain.h ||= 720
    args.state.global.dampening ||= 0.4
    args.state.global.max_speed ||= 15.0
    args.state.global.line_mapping = { :x2 => :x, :y2 => :y }
    $gtk.set_system_properties({ "log.http" => "false" }) rescue nil
  end

  def setup_camera args
    puts "*** SETUP CAMERA ***"
    args.state.camera.offset_x ||= 0
  end

  def setup_game args
    puts "*** SETUP GAME ***"
    args.state.game ||= game_new

    # Use multiplayer seed if available, otherwise random
    seed = args.state.mp && args.state.mp.terrain_seed ? args.state.mp.terrain_seed : nil
    args.state.game.terrain_segments = init_landscape(seed)
    args.state.game.terrain_lines = rebuild_terrain_lines(args.state.game.terrain_segments, args.state.global.terrain.w)
    args.state.game.terrain_dirty = false
    args.state.game.terrain_falling = false
    args.state.game.terrain_fall_speed = 0.5
    args.state.game.terrain_affected_cols = []
    args.state.game.num_players = (args.state.mp && args.state.mp.enabled) ? (args.state.mp.target_players || 2) : 2
  end

  def setup_fleas args
    puts "*** SETUP FLEAS ***"
    args.state.game.fleas = {}
    args.state.game.num_players.times do |i|
      args.state.game.fleas[i] = flea_new(i)
    end
  end

  def setup_pickups args
    puts "*** SETUP PICKUPS ***"
    args.state.game.pickups = []
    w = args.state.global.terrain.w
    segments = args.state.game.terrain_segments

    # Place health pickups randomly across the terrain
    pickup_count = 8
    pickup_count.times do |i|
      px = (rand * w).round % w
      py = terrain_top_at(segments, px, w)
      args.state.game.pickups << {
        id: i,
        pickup_type: :health,
        x: px,
        y: py + 5,
        w: 32,
        h: 24,
        value: 25,
        active: true,
        color: { r: 255, g: 255, b: 255 },
        type: "sprites/health_01.png"
      }
    end
  end

  def setup_turns args
    puts "*** SETUP TURNS ***"
    args.state.turn.current_index = 0
    args.state.turn.action = nil
    args.state.turn.number = 1
  end

  def setup_multiplayer args
    puts "*** SETUP MULTIPLAYER ***"
    args.state.mp.enabled ||= false
    args.state.mp.game_id ||= nil
    args.state.mp.local_player_index ||= nil
    args.state.mp.join_code ||= nil
    args.state.mp.terrain_seed ||= nil
    args.state.mp.last_synced_turn ||= 0
    args.state.mp.pending_request ||= nil
    args.state.mp.poll_timer ||= 0
    args.state.mp.poll_interval ||= 120
    args.state.mp.target_players ||= 2
    args.state.mp.current_player_count ||= 1
    args.state.mp.mp_state ||= :idle
    args.state.mp.replay_data ||= nil
    args.state.mp.error_message ||= nil
    args.state.mp.join_code_input ||= ""
  end
end
