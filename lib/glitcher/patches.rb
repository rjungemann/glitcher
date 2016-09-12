class Array
  def pick
    self[rand(size)]
  end

  def second
    self[1]
  end

  def third
    self[2]
  end

  def fourth
    self[3]
  end
end

class Range
  def pick
    min + rand(max - min)
  end
end

class String
  def swap(i, j)
    self[i], self[j] = self[j], self[i]
    self
  end
end
