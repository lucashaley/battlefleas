class Game
  attr_gtk
  attr_accessor :terrain, :projectiles, :playstate
  attr_accessor :player
  
  def initialize
    puts "game init"
    # puts "state: #{args.state}"
    
    @terrain = init_landscape
    @projectiles = []
    @playstate = :none
  end
  
  def set_playstate(new_playstate)
    puts "set_playstate: #{state.game.playstate} -> #{new_playstate}"
    
    @playstate = new_playstate
  end
  
  def init_landscape
    w = 1600
    frequency = 16
    frequency_variance = w * 0.01
    frequency_scale = w/frequency
    
    height_min = 200
    height_max = 300
    
    anchors = []
    zero_height = Numeric.rand(height_min..height_max)
    anchors << [0, zero_height]
    
    (frequency-1).times do |i|
      j = i+1
      anchors << [((j * frequency_scale) + Numeric.rand(-frequency_variance..frequency_variance)).floor, Numeric.rand(height_min..height_max)]
    end
    # Add the starting point for looping
    anchors << [w, zero_height]
    puts "anchors: #{anchors}"
    
    points = []
    points << anchors[0]
    anchors.each_cons(2) do |p1, p2|
      start_point = p1[0]
      end_point = p2[0]
      distance_delta = end_point - start_point
      
      start_height = p1[1]
      end_height = p2[1]
      height_delta = end_height - start_height
      
      ((start_point+1)..end_point).each do |current_point|
        perc = (current_point - start_point+1) / (distance_delta)
        eased_perc = if perc < 0.5
           4 * perc * perc * perc
         else
           1 - ((-2 * perc + 2) ** 3) / 2
         end
  
        points << [current_point, start_height + (height_delta * eased_perc)]
      end
    end
    
    lines = points.map do |x, y|
      {
        x: x,
        y: 0,
        x2: x,
        y2: y.floor,
        r: (x%(w*0.5))/10,
        g: x/40,
        b: x/10,
        a: 255, 
        blendmode_enum: 1,
        bounciness: x * 0.0005
      }
    end
    
    lines
  end
  
  def calc_projectile(p, args)
    # puts "calc_projectile: #{p}"
    return if p.is_grounded
    
    puts "Invalid position" if p.x.nil? || p.y.nil?
    
    # Apply gravity
    p.speed.y -= 0.1
    
    # Predict position
    next_x = (p.x + p.speed.x) % args.state.global.terrain.w
    next_x_rounded = next_x.round % args.state.global.terrain.w
    next_y = (p.y + p.speed.y)
    
    # check for direct vertical collision with terrain
    next_column = args.state.game.terrain[next_x_rounded]
    if next_y < next_column.y2
      # Explodes
      if p.explodes
        puts "EXPLODES!"
        p.active = false
        return false
      end
      
      # Dampening
      p.speed.y *= p.bounciness * args.state.global.dampening * next_column.bounciness
      p.speed.x *= p.bounciness * next_column.bounciness
      
      # Bounce
      next_y = next_column.y2 * 2 - next_y
      p.speed.y = -p.speed.y
    
      # Get neighbors angle
      left_x = next_x_rounded - 2
      right_x = next_x_rounded + 2
      # puts "left_x: #{left_x}, right_x: #{right_x}"
      
      left_line = { x: 0, y: 0 }
      right_line = { x: 0, y: 0 }
      
      left_line.x = left_x % args.state.global.terrain.w
      left_line.y = args.state.game.terrain[left_line.x].y2
      
      right_line.x = right_x % args.state.global.terrain.w
      right_line.y = args.state.game.terrain[right_line.x].y2
      
      slope = left_line.angle_to(right_line)
      # puts "angle: #{slope}"
      slope_sine = Math.sin(slope * Math::PI / 180)
      # puts "slope_sine: #{slope_sine}"
      p.speed.x -= slope_sine
    end
    # Finish check terrain collision
    
    # Check for grounding
    # puts "Grounding: #{(next_x - p.x).abs}, #{(next_y - p.y).abs}"
    if ((next_x - p.x).abs < 1) && ((next_y - p.y).abs < 2)
      if p.grounded_start.nil?
        p.grounded_start = Kernel.tick_count
      end
      if Kernel.tick_count - p.grounded_start > 20
        puts "grounded: #{p.name}"
        p.is_grounded = true
        p.grounded_start = nil
      end
    else
      p.grounded_start = nil
    end
    
    # Set the position for this frame
    p.x = next_x # % args.state.global.terrain.w
    p.y = next_y
    
    # set the screen position
    # This should just be for the current thing?
    p.screen_x = (args.state.camera.offset_x + p.x) % args.state.global.terrain.w
  end
end