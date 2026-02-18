module Terrain
  # Returns the highest solid y value at column x
  def terrain_top_at(segments, x, w)
    col = segments[x.round % w]
    return 0 if col.nil? || col.empty?
    top = 0
    col.each { |seg| top = seg[:top] if seg[:top] > top }
    top
  end

  # Returns true if point (x, y) is inside any solid segment at column x
  def terrain_solid_at?(segments, x, y, w)
    col = segments[x.round % w]
    return false if col.nil? || col.empty?
    col.any? { |seg| y >= seg[:bottom] && y <= seg[:top] }
  end

  # Finds segment boundary crossed during movement from (prev_x, prev_y) to (next_x, next_y).
  # Steps through every column along the horizontal path to catch steep terrain.
  # Returns { segment: seg, surface: :top or :bottom, y: surface_y } or nil
  def terrain_collision_segment(segments, prev_x, prev_y, next_x, next_y, w)
    # Determine columns to check
    px = prev_x.round % w
    nx = next_x.round % w

    # Build list of columns to step through
    if px == nx
      columns = [px]
    else
      # Handle wrapping: figure out direction and step
      dx = next_x - prev_x
      if dx > 0
        # Moving right
        if dx < w * 0.5
          columns = px <= nx ? (px..nx).to_a : ((px...w).to_a + (0..nx).to_a)
        else
          # Wrapped the other way
          columns = px >= nx ? px.downto(nx).to_a : (px.downto(0).to_a + (w - 1).downto(nx).to_a)
        end
      else
        # Moving left
        if dx.abs < w * 0.5
          columns = px >= nx ? px.downto(nx).to_a : (px.downto(0).to_a + (w - 1).downto(nx).to_a)
        else
          columns = px <= nx ? (px..nx).to_a : ((px...w).to_a + (0..nx).to_a)
        end
      end
    end

    total_steps = columns.length
    columns.each_with_index do |col_x, step|
      col = segments[col_x]
      next if col.nil? || col.empty?

      # Interpolate y at this column
      t = total_steps > 1 ? step.to_f / (total_steps - 1) : 1.0
      y_at_col = prev_y + (next_y - prev_y) * t

      # Previous y (one step back)
      if step > 0
        t_prev = (step - 1).to_f / (total_steps - 1)
        y_before = prev_y + (next_y - prev_y) * t_prev
      else
        y_before = prev_y
      end

      col.each do |seg|
        # Check if we crossed the top surface (landing)
        if y_before >= seg[:top] && y_at_col < seg[:top]
          return { segment: seg, surface: :top, y: seg[:top] }
        end

        # Check if we crossed the bottom surface (overhang)
        if y_before <= seg[:bottom] && y_at_col > seg[:bottom]
          return { segment: seg, surface: :bottom, y: seg[:bottom] }
        end

        # Check if we ended up inside a segment (fast movement or horizontal entry)
        if y_at_col >= seg[:bottom] && y_at_col <= seg[:top]
          dist_to_top = seg[:top] - y_at_col
          dist_to_bottom = y_at_col - seg[:bottom]
          if dist_to_top <= dist_to_bottom
            return { segment: seg, surface: :top, y: seg[:top] }
          else
            return { segment: seg, surface: :bottom, y: seg[:bottom] }
          end
        end
      end
    end

    nil
  end

  # Returns nearest segment surface y for grounding check
  def terrain_nearest_surface(segments, x, y, w)
    col = segments[x.round % w]
    return nil if col.nil? || col.empty?

    nearest = nil
    nearest_dist = 999999

    col.each do |seg|
      # Check distance to top surface
      dist_top = (y - seg[:top]).abs
      if dist_top < nearest_dist
        nearest_dist = dist_top
        nearest = seg[:top]
      end
      # Check distance to bottom surface (overhang underside)
      dist_bottom = (y - seg[:bottom]).abs
      if dist_bottom < nearest_dist
        nearest_dist = dist_bottom
        nearest = seg[:bottom]
      end
    end

    { y: nearest, dist: nearest_dist }
  end

  # Convert segment data to flat array of line hashes for rendering
  def rebuild_terrain_lines(segments, w)
    lines = []
    segments.each_with_index do |col, x|
      next if col.nil?
      col.each do |seg|
        lines << {
          x: x, y: seg[:bottom],
          x2: x, y2: seg[:top],
          r: seg[:r], g: seg[:g], b: seg[:b],
          a: 255, blendmode_enum: 1
        }
      end
    end
    lines
  end

  # Remove a full circle from terrain segments
  def carve_circle(segments, cx, cy, radius, w)
    affected = []
    (-radius..radius).each do |dx|
      col_x = (cx + dx).round % w
      col = segments[col_x]
      next if col.nil? || col.empty?

      h = Math.sqrt(radius * radius - dx * dx)
      circle_bottom = (cy - h).floor
      circle_top = (cy + h).ceil

      new_col = []
      col.each do |seg|
        # No overlap — keep segment as-is
        if seg[:top] < circle_bottom || seg[:bottom] > circle_top
          new_col << seg
          next
        end

        # Segment fully inside circle — remove it
        if seg[:bottom] >= circle_bottom && seg[:top] <= circle_top
          next
        end

        # Circle cuts through middle — split into two segments
        if seg[:bottom] < circle_bottom && seg[:top] > circle_top
          new_col << seg.merge(top: circle_bottom)
          new_col << seg.merge(bottom: circle_top)
          next
        end

        # Circle cuts top of segment
        if seg[:bottom] < circle_bottom && seg[:top] >= circle_bottom
          new_col << seg.merge(top: circle_bottom)
          next
        end

        # Circle cuts bottom of segment
        if seg[:top] > circle_top && seg[:bottom] <= circle_top
          new_col << seg.merge(bottom: circle_top)
          next
        end
      end

      # Remove tiny segments (less than 2px)
      segments[col_x] = new_col.select { |s| s[:top] - s[:bottom] > 1 }
      affected << col_x
    end
    affected
  end

  # Per-frame: drop unsupported segments, merge when they land
  def process_falling_terrain(args)
    segments = args.state.game.terrain_segments
    w = args.state.global.terrain.w
    fall_speed = args.state.game.terrain_fall_speed || 2
    all_settled = true

    segments.each_with_index do |col, x|
      next if col.nil? || col.length < 2

      # Sort by bottom ascending
      segments[x] = col.sort_by { |s| s[:bottom] }
      col = segments[x]

      i = 1
      while i < col.length
        seg = col[i]
        support_top = col[i - 1][:top]

        if seg[:bottom] > support_top + 1
          # This segment is floating — drop it
          drop = [seg[:bottom] - support_top, fall_speed].min
          seg[:bottom] -= drop
          seg[:top] -= drop
          all_settled = false
          args.state.game.terrain_dirty = true

          # Check if it has merged with the segment below
          if seg[:bottom] <= support_top
            # Merge: extend lower segment's top, keep the higher top
            col[i - 1][:top] = seg[:top] if seg[:top] > col[i - 1][:top]
            col.delete_at(i)
            next
          end
        end
        i += 1
      end
    end

    args.state.game.terrain_falling = false if all_settled
  end
end
