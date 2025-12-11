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
end