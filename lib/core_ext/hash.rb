class Hash
  # @see https://gist.github.com/henrik/146844
  def diff(b)
    a = self
    (a.keys | b.keys).inject({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
          diff[k] = a[k].deep_diff(b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end

  def each_pair_recursively(parent = [])
    self.each_pair do |k,v|
      if v.is_a?(Hash)
        v.each_pair_recursive(parent + [k]) { |k,v| yield k, v}
      else
        yield(parent + [k], v)
      end
    end
  end
end