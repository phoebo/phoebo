class Array
  def to_h_by(id)
    h = {}

      each do |item|
        h[item[id]] = item
      end

      h
  end
end