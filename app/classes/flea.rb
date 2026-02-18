class Flea < BattleSprite

  attr_accessor :aim

  def initialize(args)
    puts "*** Flea Initialize ***"
    super args

    @aim = {
      angle: 0,
      power: 0
    }
  end
end