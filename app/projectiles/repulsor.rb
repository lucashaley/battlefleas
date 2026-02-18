class RepulsorProjectile < Projectile
  attr_accessor :impulse_radius, :impulse_strength, :impulse_lift

  def initialize(args = nil)
    super(args)
    @name = "Repulsor"
    @bounciness = 0.3
    @blast_radius = 0
    @color = { r: 128, g: 0, b: 255 }
    @impulse_radius = 60
    @impulse_strength = 20.0
    @impulse_lift = 10.0
  end

  def has_terrain_impact?
    true
  end

  def on_impact(args, hit_x, hit_y)
    args.state.game.fleas.each_value do |flea|
      next unless flea.alive

      dx = ((hit_x - flea.x + 800) % 1600) - 800
      dy = hit_y - flea.y
      dist = Math.sqrt(dx * dx + dy * dy)
      next if dist >= @impulse_radius || dist < 0.1

      proximity = 1.0 - dist / @impulse_radius
      factor = proximity * @impulse_strength
      norm_x = -dx / dist
      norm_y = -dy / dist

      norm_y = 0 if norm_y < 0

      len = Math.sqrt(norm_x * norm_x + norm_y * norm_y)
      if len > 0.01
        norm_x /= len
        norm_y /= len
      end

      flea.speed.x += norm_x * factor
      flea.speed.y += norm_y * factor
      flea.speed.y += proximity * @impulse_lift

      flea.is_grounded = false
      flea.grounded_start = nil
    end
  end
end

Projectile.register(:repulsor, RepulsorProjectile)
