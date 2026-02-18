class ShotgunProjectile < Projectile
  def initialize(args = nil)
    super(args)
    @name = "Shotgun"
    @bounciness = 0.5
    @blast_radius = 10
    @damage = 40
    @color = { r: 255, g: 165, b: 0 }
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

  def spawn(flea)
    spread = 10.0
    offsets = [-spread / 2.0, 0, spread / 2.0]

    offsets.map do |offset|
      p = ShotgunProjectile.new
      p.projectile_type = :shotgun

      angle = flea.aim.angle + offset
      aim_x = Math.cos(angle * Math::PI / 180)
      aim_y = Math.sin(angle * Math::PI / 180)

      p.x = (flea.x + aim_x * 20).round
      p.y = (flea.y + aim_y * 20).round + 5
      p.speed = { x: aim_x * flea.aim.power * 0.1, y: aim_y * flea.aim.power * 0.1 }
      p
    end
  end
end

Projectile.register(:shotgun, ShotgunProjectile)
