module UserInterface
  def powerbar player_power
    output = []
    output << {
      x: 40,
      y: 40,
      w: 40,
      h: 400,
      path: :solid,
      r: 0,
      g: 0,
      b: 0,
      a: 255
    }
    output << {
      x: 42,
      y: 42,
      w: 36,
      h: 396,
      path: :solid,
      r: 128,
      g: 128,
      b: 128,
      a: 255
    }
    output << {
      x: 42,
      y: 42,
      w: 36,
      h: 396 * player_power * 0.01,
      path: :solid,
      r: 255,
      g: 255,
      b: 255,
      a: 255
    }
  end

  def health_display(flea)
    health = flea.health || 0
    health_pct = health / 100.0
    bar_r = ((1 - health_pct) * 255).to_i
    bar_g = (health_pct * 255).to_i

    output = []
    # Background
    output << {
      x: 100, y: 40, w: 160, h: 30,
      path: :solid, r: 40, g: 40, b: 40, a: 220
    }
    # Health bar fill
    output << {
      x: 102, y: 42, w: (156 * health_pct).round, h: 26,
      path: :solid, r: bar_r, g: bar_g, b: 0, a: 255
    }
    output
  end

  def health_label(flea)
    health = flea.health || 0
    [
      {
        x: 180, y: 62,
        text: "HP: #{health}",
        size_enum: 0,
        alignment_enum: 1,
        r: 255, g: 255, b: 255, a: 255
      }
    ]
  end

  def turn_indicator(flea, turn_number)
    [
      {
        x: 640,
        y: 700,
        text: "#{flea.name} -- Turn #{turn_number}",
        size_enum: 1,
        alignment_enum: 1,
        r: flea.color.r,
        g: flea.color.g,
        b: flea.color.b,
        a: 255
      }
    ]
  end

  def waiting_indicator
    # Pulsing alpha based on tick count
    alpha = 128 + (127 * Math.sin(Kernel.tick_count * 0.05)).to_i
    [
      {
        x: 640,
        y: 400,
        text: "Waiting for opponent...",
        size_enum: 2,
        alignment_enum: 1,
        r: 255,
        g: 255,
        b: 255,
        a: alpha
      }
    ]
  end

  def weapon_indicator(flea)
    weapon_key = flea.weapon || :explosive
    type = Projectile.type_info(weapon_key)
    name = type ? type[:name] : weapon_key.to_s
    color = type ? type[:color] : { r: 255, g: 255, b: 255 }
    [
      {
        x: 60,
        y: 460,
        text: name,
        size_enum: -1,
        alignment_enum: 1,
        r: color[:r],
        g: color[:g],
        b: color[:b],
        a: 255
      }
    ]
  end

  def action_buttons
    output = []

    # JUMP button
    # Border
    output << { x: 1080, y: 40, w: 80, h: 50, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    # Green fill
    output << { x: 1082, y: 42, w: 76, h: 46, path: :solid, r: 0, g: 180, b: 0, a: 255 }

    # FIRE button
    # Border
    output << { x: 1180, y: 40, w: 80, h: 50, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    # Red fill
    output << { x: 1182, y: 42, w: 76, h: 46, path: :solid, r: 200, g: 0, b: 0, a: 255 }

    output
  end

  def action_button_labels
    [
      { x: 1120, y: 75, text: "JUMP", size_enum: 0, alignment_enum: 1, r: 255, g: 255, b: 255, a: 255 },
      { x: 1220, y: 75, text: "FIRE", size_enum: 0, alignment_enum: 1, r: 255, g: 255, b: 255, a: 255 }
    ]
  end

  def join_code_display(code)
    [
      {
        x: 640,
        y: 500,
        text: "Join Code: #{code}",
        size_enum: 3,
        alignment_enum: 1,
        r: 255,
        g: 255,
        b: 0,
        a: 255
      }
    ]
  end

  def mp_error_display(message)
    [
      {
        x: 640,
        y: 360,
        text: message,
        size_enum: 1,
        alignment_enum: 1,
        r: 255,
        g: 64,
        b: 64,
        a: 255
      },
      {
        x: 640,
        y: 330,
        text: "Press ESC to return to menu",
        size_enum: 0,
        alignment_enum: 1,
        r: 200,
        g: 200,
        b: 200,
        a: 255
      }
    ]
  end

  def join_code_input_display(input_text)
    [
      {
        x: 640,
        y: 420,
        text: "Enter 6-digit code:",
        size_enum: 1,
        alignment_enum: 1,
        r: 255,
        g: 255,
        b: 255,
        a: 255
      },
      {
        x: 640,
        y: 380,
        text: input_text + "_",
        size_enum: 3,
        alignment_enum: 1,
        r: 255,
        g: 255,
        b: 0,
        a: 255
      },
      {
        x: 640,
        y: 340,
        text: "Press ENTER to join, ESC to cancel",
        size_enum: 0,
        alignment_enum: 1,
        r: 200,
        g: 200,
        b: 200,
        a: 255
      }
    ]
  end
end
