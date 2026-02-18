module Landscape
  def init_landscape(seed = nil)
    srand(seed) if seed
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

    segments = Array.new(w) { [] }
    points.each do |x, y|
      segments[x] = [{
        bottom: 0,
        top: y.floor,
        r: (x % (w * 0.5)) / 10,
        g: x / 40,
        b: x / 10,
        bounciness: x * 0.0005
      }]
    end

    segments
  end
end