module Game
  def game_new
    {
      playstate: :none,
      terrain_segments: [],
      terrain_lines: [],
      terrain_dirty: false,
      terrain_falling: false,
      terrain_fall_speed: 0.5,
      terrain_affected_cols: [],
      projectiles: [],
      pickups: []
    }
  end
end
