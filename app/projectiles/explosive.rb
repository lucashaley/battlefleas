class ExplosiveProjectile < Projectile
  def initialize(args = nil)
    super(args)
    @name = "Explosive"
    @bounciness = 0.5
    @blast_radius = 20
    @color = { r: 0, g: 128, b: 64 }
  end

  def explodes_on_flea?
    true
  end

  def explodes_on_terrain?
    true
  end

  def on_impact(args, hit_x, hit_y)
    explode_at(args, hit_x, hit_y, @blast_radius, @damage, @owner_index)
  end
end

Projectile.register(:explosive, ExplosiveProjectile)
