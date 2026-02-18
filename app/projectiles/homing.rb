class HomingProjectile < Projectile
  DETECTION_RADIUS = 80
  TURN_RATE = 0.15

  def initialize(args = nil)
    super(args)
    @name = "Homing"
    @bounciness = 0.5
    @blast_radius = 15
    @damage = 70
    @color = { r: 255, g: 50, b: 50 }
    @locked = false
  end

  def explodes_on_flea?
    true
  end

  def explodes_on_terrain?
    true
  end

  def on_impact(args, hit_x, hit_y)
    explode_at(args, hit_x, hit_y, @blast_radius, @damage)
  end

  def track_nearest_flea(args)
    nearest = nil
    nearest_dist = DETECTION_RADIUS

    args.state.game.fleas.each_value do |flea|
      next unless flea.alive

      dx = ((flea.x - @x + 800) % 1600) - 800
      dy = flea.y - @y
      dist = Math.sqrt(dx * dx + dy * dy)

      if dist < nearest_dist
        nearest_dist = dist
        nearest = flea
      end
    end

    return unless nearest

    dx = ((nearest.x - @x + 800) % 1600) - 800
    dy = nearest.y - @y
    dist = Math.sqrt(dx * dx + dy * dy)

    # Normalize direction to target
    dir_x = dx / dist
    dir_y = dy / dist

    # Current speed magnitude
    spd = Math.sqrt(@speed[:x] * @speed[:x] + @speed[:y] * @speed[:y])
    spd = 1.0 if spd < 0.1

    # Current direction
    cur_x = @speed[:x] / spd
    cur_y = @speed[:y] / spd

    # Steer toward target
    new_x = cur_x + (dir_x - cur_x) * TURN_RATE
    new_y = cur_y + (dir_y - cur_y) * TURN_RATE

    # Re-normalize and apply original speed
    len = Math.sqrt(new_x * new_x + new_y * new_y)
    if len > 0.01
      @speed[:x] = (new_x / len) * spd
      @speed[:y] = (new_y / len) * spd
    end

    @locked = true
  end
end

Projectile.register(:homing, HomingProjectile)
