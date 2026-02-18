class Projectile < BattleSprite
  REGISTRY = {}

  attr_accessor :active, :projectile_type, :w, :h, :x, :y, :screen_x,
                :speed, :bounciness, :is_grounded, :grounded_start,
                :blast_radius, :damage, :color, :type, :name, :next_x, :next_y

  def initialize(args = nil)
    if args
      super(args)
    end

    @name = 'projectile'
    @active = true
    @projectile_type = nil
    @w = 7
    @h = 7
    @x = 400
    @y = 400
    @next_x = 0
    @next_y = 0
    @screen_x = 400
    @speed = { x: 1, y: 4 }
    @bounciness = 0.9
    @is_grounded = false
    @grounded_start = nil
    @blast_radius = 0
    @damage = 100
    @color = { r: 196, g: 16, b: 64 }
    @type = :solid
  end

  # --- Overridable methods (subclasses override these) ---

  def explodes_on_flea?
    false
  end

  def explodes_on_terrain?
    false
  end

  def has_terrain_impact?
    false
  end

  def on_impact(args, hit_x, hit_y)
    # no-op by default
  end

  def spawn(flea)
    aim_x = Math.cos(flea.aim.angle * Math::PI / 180)
    aim_y = Math.sin(flea.aim.angle * Math::PI / 180)

    @x = (flea.x + aim_x * 20).round
    @y = (flea.y + aim_y * 20).round + 5
    @speed = { x: aim_x * flea.aim.power * 0.1, y: aim_y * flea.aim.power * 0.1 }

    [self]
  end

  # --- Class-level factory and registry ---

  def self.register(type_key, klass)
    REGISTRY[type_key] = klass
  end

  def self.create(type_key)
    klass = REGISTRY[type_key] || REGISTRY[:explosive]
    instance = klass.new
    instance.projectile_type = type_key
    instance
  end

  def self.available_weapons
    REGISTRY.keys
  end

  def self.type_info(type_key)
    klass = REGISTRY[type_key]
    return nil unless klass
    instance = klass.new
    { name: instance.name, color: instance.color }
  end
end
