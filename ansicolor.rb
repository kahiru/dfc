module Colors
  WHITE="\e[29m"
  GRAY="\e[30m"
  RED="\033[31;1m"
  GREEN="\033[32;1m"
  YELLOW="\033[33;1m"
  BLUE="\033[34;1m"
  PURPLE="\033[35;1m"
  CYAN="\033[36;1m"
  RESET="\033[0m"
end

class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def pink
    colorize(35)
  end

  def gray
    colorize(30)
  end
  def blue
    colorize(34)
  end

  def purple
    colorize(35)
  end

  def cyan
    colorize(36)
  end
end
