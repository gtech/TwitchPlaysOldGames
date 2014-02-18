module DisplayTime
  class Fixnum
    def year
      self * 365 * 24 * 60 * 60
    end
    def month
      self * 30 * 24 * 60 * 60
    end
    def week
      self * 7 * 24 * 60 * 60
    end
    def day
      self * 24 * 60 * 60
    end
    def hour
      self * 60 * 60
    end
    def minute
      self * 60
    end
    def second
      self 
    end
  end

  def pluralize(n, unit)
    if n > 1
      n.to_s + " " + unit.to_s + "s"
    else
      n.to_s + " " + unit.to_s
    end
  end
  
  def time_diff_in_natural_language(from_time, to_time)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    distance_in_seconds = ((to_time - from_time).abs).round
    components = []

    %w(year month week day hour minute second).each do |interval|
      # For each interval type, if the amount of time remaining is greater than
      # one unit, calculate how many units fit into the remaining time.
      if distance_in_seconds >= 1.send(interval)
        delta = (distance_in_seconds / 1.send(interval)).floor
        distance_in_seconds -= delta.send(interval)
        components << pluralize(delta, interval)
      end
    end

    components.join(", ")
  end
end
