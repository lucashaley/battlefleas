module Multiplayer
  SUPABASE_URL = "https://ketcxeidfgejojzefzkd.supabase.co/rest/v1"
  SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtldGN4ZWlkZmdlam9qemVmemtkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MDg4MzcsImV4cCI6MjA3MTI4NDgzN30.eVMluWN13MhFFOHv_V0kzwrBpXkfp5sUV97kbad1eYk"

  # --- JSON Serializer (mRuby has no to_json) ---

  def to_json(obj)
    case obj
    when nil
      "null"
    when true, false
      obj.to_s
    when Integer, Float
      obj.to_s
    when String
      "\"#{obj.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
    when Symbol
      to_json(obj.to_s)
    when Array
      "[#{obj.map { |v| to_json(v) }.join(",")}]"
    when Hash
      pairs = obj.map { |k, v| "#{to_json(k.to_s)}:#{to_json(v)}" }
      "{#{pairs.join(",")}}"
    else
      to_json(obj.to_s)
    end
  end

  # --- HTTP Helpers ---

  def supabase_headers
    [
      "apikey: #{SUPABASE_ANON_KEY}",
      "authorization: Bearer #{SUPABASE_ANON_KEY}",
      "content-type: application/json",
      "prefer: return=representation"
    ]
  end

  def supabase_get(args, path)
    url = "#{SUPABASE_URL}/#{path}"
    args.gtk.http_get(url, supabase_headers)
  end

  def supabase_post(args, table, data)
    url = "#{SUPABASE_URL}/#{table}"
    body = to_json(data)
    args.gtk.http_post_body(url, body, supabase_headers)
  end

  def supabase_rpc(args, function_name, params)
    url = "#{SUPABASE_URL.gsub('/rest/v1', '')}/rest/v1/rpc/#{function_name}"
    body = to_json(params)
    args.gtk.http_post_body(url, body, supabase_headers)
  end

  # --- Game Creation / Joining ---

  def mp_create_game(args, target_players = 2)
    seed = (rand * 999999).to_i
    code = generate_join_code

    args.state.mp.terrain_seed = seed
    args.state.mp.join_code = code
    args.state.mp.local_player_index = 0
    args.state.mp.target_players = target_players
    args.state.mp.mp_state = :creating

    args.state.mp.pending_request = supabase_post(args, "games", {
      join_code: code,
      terrain_seed: seed,
      player_count: 1,
      target_players: target_players,
      status: "waiting"
    })
  end

  def mp_join_game(args, join_code)
    args.state.mp.join_code = join_code
    args.state.mp.mp_state = :joining_rpc

    # RPC atomically increments player_count, assigns index, sets active when full
    args.state.mp.pending_request = supabase_rpc(args, "join_game", {
      p_join_code: join_code
    })
  end

  def generate_join_code
    code = ""
    6.times { code += (rand * 10).to_i.to_s }
    code
  end

  # --- Per-frame Multiplayer Tick ---

  def mp_tick(args)
    return unless args.state.mp.enabled

    mp = args.state.mp

    # Check pending HTTP requests
    if mp.pending_request
      req = mp.pending_request
      if req[:complete]
        handle_http_response(args, req)
        mp.pending_request = nil
      end
      return
    end

    case mp.mp_state
    when :waiting_for_opponent
      # Poll for opponent joining
      mp.poll_timer += 1
      if mp.poll_timer >= mp.poll_interval
        mp.poll_timer = 0
        mp.pending_request = supabase_get(
          args,
          "games?id=eq.#{mp.game_id}&select=*"
        )
        mp.mp_state = :checking_opponent
      end

    when :polling
      # Poll for opponent's turn
      mp.poll_timer += 1
      if mp.poll_timer >= mp.poll_interval
        mp.poll_timer = 0
        mp_poll_turn(args)
      end
    end
  end

  def handle_http_response(args, req)
    mp = args.state.mp

    if req[:http_response_code] != 200 && req[:http_response_code] != 201
      puts "HTTP Error: #{req[:http_response_code]}"
      puts "Response: #{req[:response_data]}"
      mp.mp_state = :error
      mp.error_message = "Network error (#{req[:http_response_code]})"
      return
    end

    data = args.gtk.parse_json(req[:response_data])

    case mp.mp_state
    when :creating
      # Game created successfully
      if data && data.length > 0
        row = data[0]
        mp.game_id = row["id"]
        mp.mp_state = :waiting_for_opponent
        mp.poll_timer = 0
        puts "Game created! Code: #{mp.join_code}, ID: #{mp.game_id}"
      else
        mp.mp_state = :error
        mp.error_message = "Failed to create game"
      end

    when :joining_rpc
      # RPC returns {game_id, terrain_seed, player_index, player_count, target_players}
      if data && data.is_a?(Array) && data.length > 0
        row = data[0]
        mp.game_id = row["game_id"]
        mp.terrain_seed = row["terrain_seed"].to_i
        mp.local_player_index = row["player_index"].to_i
        mp.target_players = row["target_players"].to_i
        current_count = row["player_count"].to_i

        if current_count >= mp.target_players
          mp.mp_state = :ready
          puts "Joined game #{mp.game_id} as player #{mp.local_player_index + 1} — game full, starting!"
        else
          mp.mp_state = :waiting_for_opponent
          mp.poll_timer = 0
          puts "Joined game #{mp.game_id} as player #{mp.local_player_index + 1} — waiting for #{mp.target_players - current_count} more"
        end
      else
        mp.mp_state = :error
        mp.error_message = "Game not found or already full"
      end

    when :checking_opponent
      if data && data.length > 0
        row = data[0]
        current_count = row["player_count"].to_i
        target = mp.target_players || 2
        mp.current_player_count = current_count
        if current_count >= target
          mp.mp_state = :ready
          puts "All #{target} players joined! Starting game."
        else
          mp.mp_state = :waiting_for_opponent
        end
      else
        mp.mp_state = :waiting_for_opponent
      end

    when :uploading
      # Turn uploaded successfully — update last_synced_turn so we don't re-fetch our own turn
      sync_turn = (args.state.turn.number - 1) * args.state.game.num_players + args.state.turn.current_index + 1
      mp.last_synced_turn = sync_turn
      puts "Turn #{sync_turn} uploaded successfully"
      mp.mp_state = :idle
      mp.replay_data = nil
      args.state.game.terrain_affected_cols = []
      advance_turn(args)
      args.state.game.playstate = :interact

    when :polling_check
      if data && data.length > 0
        row = data[0]
        turn_data = parse_turn_data(args, row)
        mp.replay_data = turn_data
        mp.last_synced_turn = turn_data[:turn_number]
        mp.mp_state = :replaying
        mp_replay_action(args, turn_data)
      else
        # No turn yet, keep polling
        mp.mp_state = :polling
      end
    end
  end

  # --- Turn Upload ---

  def mp_upload_turn(args)
    mp = args.state.mp
    flea = current_flea(args)

    turn_number = args.state.turn.number
    # Build turn number based on turn.number and current_index
    sync_turn = (args.state.turn.number - 1) * args.state.game.num_players + args.state.turn.current_index + 1

    payload = {
      game_id: mp.game_id,
      turn_number: sync_turn,
      player_index: mp.local_player_index,
      action: args.state.turn.action.to_s,
      aim_angle: flea.aim.angle,
      aim_power: flea.aim.power,
      weapon: flea.weapon.to_s,
      result_fleas: serialize_fleas(args.state.game.fleas),
      result_terrain_diff: compute_terrain_diff(args, serialize_pickups(args))
    }

    mp.mp_state = :uploading
    mp.pending_request = supabase_post(args, "turns", payload)
  end

  # --- Turn Polling ---

  def mp_poll_turn(args)
    mp = args.state.mp
    next_turn = mp.last_synced_turn + 1

    mp.mp_state = :polling_check
    mp.pending_request = supabase_get(
      args,
      "turns?game_id=eq.#{mp.game_id}&turn_number=eq.#{next_turn}&select=*"
    )
  end

  # --- Replay & Authoritative State ---

  def parse_turn_data(args, row)
    fleas_data = row["result_fleas"]
    fleas_data = args.gtk.parse_json(fleas_data) if fleas_data.is_a?(String)

    terrain_diff = row["result_terrain_diff"]
    terrain_diff = args.gtk.parse_json(terrain_diff) if terrain_diff.is_a?(String)

    weapon_str = row["weapon"] || "explosive"
    {
      turn_number: row["turn_number"].to_i,
      player_index: row["player_index"].to_i,
      action: row["action"].to_s.to_sym,
      aim_angle: row["aim_angle"].to_f,
      aim_power: row["aim_power"].to_f,
      weapon: weapon_str.to_sym,
      result_fleas: fleas_data,
      result_terrain_diff: terrain_diff
    }
  end

  def mp_replay_action(args, turn_data)
    # Find the opponent flea and set their aim
    opponent_index = turn_data[:player_index]
    opponent_flea = args.state.game.fleas[opponent_index]
    opponent_flea.aim.angle = turn_data[:aim_angle]
    opponent_flea.aim.power = turn_data[:aim_power]

    case turn_data[:action]
    when :jump
      x_offset = Math.cos(opponent_flea.aim.angle * Math::PI / 180)
      y_offset = Math.sin(opponent_flea.aim.angle * Math::PI / 180)
      relative_power = opponent_flea.aim.power * 0.1
      opponent_flea.speed.x = x_offset * relative_power
      opponent_flea.speed.y = y_offset * relative_power
      opponent_flea.is_grounded = false
      opponent_flea.grounded_start = nil

      args.state.turn.action = :jump
      args.state.game.playstate = :review

    when :fire
      aim_x = Math.cos(opponent_flea.aim.angle * Math::PI / 180)
      aim_y = Math.sin(opponent_flea.aim.angle * Math::PI / 180)

      muzzle_x = (opponent_flea.x + aim_x * 20).round
      muzzle_y = (opponent_flea.y + aim_y * 20).round + 5

      weapon = turn_data[:weapon] || :explosive
      args.state.game.projectiles << init_projectile(weapon).tap do |b|
        b.x = muzzle_x
        b.y = muzzle_y
        b.speed = { x: aim_x * opponent_flea.aim.power * 0.1, y: aim_y * opponent_flea.aim.power * 0.1 }
      end

      args.state.turn.action = :fire
      args.state.game.playstate = :review
    end
  end

  def mp_apply_authoritative_state(args, turn_data)
    return unless turn_data

    # Apply authoritative flea positions
    if turn_data[:result_fleas]
      apply_flea_state(args.state.game.fleas, turn_data[:result_fleas])
    end

    # Apply terrain diff
    if turn_data[:result_terrain_diff]
      apply_terrain_diff(args.state.game.terrain_segments, turn_data[:result_terrain_diff])
      args.state.game.terrain_dirty = true

      # Apply pick-up state
      pickup_data = turn_data[:result_terrain_diff]["_pickups"]
      if pickup_data
        apply_pickup_state(args.state.game.pickups, pickup_data)
      end
    end
  end

  # --- Serialization ---

  def serialize_fleas(fleas)
    result = []
    fleas.each do |index, flea|
      result << {
        index: index,
        x: flea.x.round(2),
        y: flea.y.round(2),
        speed_x: flea.speed.x.round(4),
        speed_y: flea.speed.y.round(4),
        is_grounded: flea.is_grounded,
        alive: flea.alive,
        health: flea.health
      }
    end
    result
  end

  def apply_flea_state(fleas, data)
    data.each do |fd|
      # Handle both string and symbol keys
      idx = (fd["index"] || fd[:index]).to_i
      flea = fleas[idx]
      next unless flea

      flea.x = (fd["x"] || fd[:x]).to_f
      flea.y = (fd["y"] || fd[:y]).to_f
      flea.speed.x = (fd["speed_x"] || fd[:speed_x]).to_f
      flea.speed.y = (fd["speed_y"] || fd[:speed_y]).to_f
      flea.is_grounded = fd["is_grounded"] || fd[:is_grounded]
      flea.grounded_start = nil
      flea.alive = fd["alive"] || fd[:alive]
      flea.health = (fd["health"] || fd[:health]).to_i
    end
  end

  # --- Terrain Diff ---

  def snapshot_terrain(segments)
    snapshot = {}
    segments.each_with_index do |col, x|
      next if col.nil? || col.empty?
      snapshot[x] = col.length
    end
    snapshot
  end

  def compute_terrain_diff(args, pickup_data = nil)
    affected_cols = args.state.game.terrain_affected_cols
    diff = {}

    if affected_cols && !affected_cols.empty?
      segments = args.state.game.terrain_segments
      affected_cols.uniq.each do |col_x|
        col = segments[col_x]
        if col.nil? || col.empty?
          diff[col_x.to_s] = []
        else
          diff[col_x.to_s] = col.map do |seg|
            {
              bottom: seg[:bottom],
              top: seg[:top],
              r: seg[:r],
              g: seg[:g],
              b: seg[:b],
              bounciness: seg[:bounciness]
            }
          end
        end
      end
    end

    # Include pickup state in the diff payload
    diff["_pickups"] = pickup_data if pickup_data

    diff
  end

  def serialize_pickups(args)
    collected = []
    args.state.game.pickups.each do |p|
      collected << p.id unless p.active
    end
    collected
  end

  def apply_pickup_state(pickups, collected_ids)
    return if collected_ids.nil?
    pickups.each do |p|
      id = p.id.is_a?(String) ? p.id.to_i : p.id
      if collected_ids.include?(id)
        p.active = false
      end
    end
  end

  def apply_terrain_diff(segments, diff)
    return if diff.nil?

    diff.each do |col_x_str, col_data|
      next if col_x_str[0] == "_"  # skip metadata keys like _pickups
      col_x = col_x_str.to_i
      if col_data.nil? || (col_data.is_a?(Array) && col_data.empty?)
        segments[col_x] = []
      else
        segments[col_x] = col_data.map do |seg_data|
          {
            bottom: (seg_data["bottom"] || seg_data[:bottom]).to_f,
            top: (seg_data["top"] || seg_data[:top]).to_f,
            r: (seg_data["r"] || seg_data[:r]).to_i,
            g: (seg_data["g"] || seg_data[:g]).to_i,
            b: (seg_data["b"] || seg_data[:b]).to_i,
            bounciness: (seg_data["bounciness"] || seg_data[:bounciness]).to_f
          }
        end
      end
    end
  end

  # --- Helpers ---

  def is_local_turn?(args)
    args.state.turn.current_index == args.state.mp.local_player_index
  end

  def mp_start_polling(args)
    args.state.mp.mp_state = :polling
    args.state.mp.poll_timer = 0
  end
end
