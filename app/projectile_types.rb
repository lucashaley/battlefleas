module ProjectileTypes
  PROJECTILE_TYPES = {
    explosive: {
      name: "Explosive",
      color: { r: 0, g: 128, b: 64 },
      blast_radius: 20,
      bounciness: 0.5,
      explodes_on_terrain: true,
      explodes_on_flea: true
    },
    repulsor: {
      name: "Repulsor",
      color: { r: 128, g: 0, b: 255 },
      blast_radius: 0,
      bounciness: 0.3,
      explodes_on_terrain: false,
      explodes_on_flea: false,
      impulse_radius: 60,
      impulse_strength: 20.0,
      impulse_lift: 10.0
    }
  }

  def init_projectile(type_key)
    type = PROJECTILE_TYPES[type_key] || PROJECTILE_TYPES[:explosive]
    {
      active: true,
      name: 'projectile',
      projectile_type: type_key,
      w: 7, h: 7,
      x: 400, y: 400,
      next_x: 0, next_y: 0,
      screen_x: 400,
      speed: { x: 1, y: 4 },
      bounciness: type[:bounciness],
      is_grounded: false,
      grounded_start: nil,
      blast_radius: type[:blast_radius],
      color: { r: type[:color][:r], g: type[:color][:g], b: type[:color][:b] },
      type: :solid
    }
  end

  def projectile_on_impact(args, projectile, hit_x, hit_y)
    type_key = projectile.projectile_type
    return unless type_key

    case type_key
    when :explosive
      explode_at(args, hit_x, hit_y, projectile.blast_radius || 20)
    when :repulsor
      type = PROJECTILE_TYPES[:repulsor]
      impact_repulsor(args, hit_x, hit_y, type[:impulse_radius], type[:impulse_strength], type[:impulse_lift])
    end
  end

  def impact_repulsor(args, cx, cy, radius, strength, lift)
    args.state.game.fleas.each_value do |flea|
      next unless flea.alive

      dx = ((cx - flea.x + 800) % 1600) - 800
      dy = cy - flea.y
      dist = Math.sqrt(dx * dx + dy * dy)
      next if dist >= radius || dist < 0.1

      # Push away from impact — stronger when closer
      proximity = 1.0 - dist / radius
      factor = proximity * strength
      norm_x = -dx / dist
      norm_y = -dy / dist

      # Never push downward into terrain — clamp Y impulse to upward/zero
      norm_y = 0 if norm_y < 0

      # Re-normalize so total impulse magnitude stays consistent
      len = Math.sqrt(norm_x * norm_x + norm_y * norm_y)
      if len > 0.01
        norm_x /= len
        norm_y /= len
      end

      flea.speed.x += norm_x * factor
      flea.speed.y += norm_y * factor

      # Additional upward lift scaled by proximity
      flea.speed.y += proximity * lift

      flea.is_grounded = false
      flea.grounded_start = nil
    end
  end

  def available_weapons
    PROJECTILE_TYPES.keys
  end
end
