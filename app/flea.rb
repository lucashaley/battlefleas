module Flea
  FLEA_COLORS = [
    { r: 196, g: 16, b: 64 },   # red
    { r: 16, g: 64, b: 196 },   # blue
    { r: 16, g: 196, b: 64 }    # green
  ]

  def flea_new(index = 0)
    color = FLEA_COLORS[index % FLEA_COLORS.length]
    start_x = (rand * 1600).round
    {
      index: index,
      name: "Player #{index + 1}",
      x: start_x,
      y: 500,
      w: 10,
      h: 10,
      next_x: start_x,
      next_y: 500,
      screen_x: 0,
      speed: { x: 0, y: 0 },
      bounciness: 0.9,
      is_grounded: false,
      grounded_start: nil,
      aim: { angle: 90, power: 50 },
      color: color,
      type: :solid,
      controller: :human,
      alive: true,
      health: 100,
      weapon: :explosive
    }
  end
end
