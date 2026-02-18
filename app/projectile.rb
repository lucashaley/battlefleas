class Projectile < BattleSprite
  def initialize(args)
    puts "*** Projectile Initialize ***"
    super args

    @name = "projectile"
    @w = 10
    @h = 10
    @x ||= rand() * args.state.global.terrain.w
    @y ||= 600

    @next_x ||= @x
    @next_y ||= @y

    @speed = {
      x: -1,
      y: 1
    }

    @bounciness ||= 0.9
    @is_grounded ||= false
    @color = { r: 196, g: 16, b: 64 }
    @type = :solid
    @screen_x = 0
  end
end