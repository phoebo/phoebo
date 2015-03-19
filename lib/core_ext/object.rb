class Object
  # @see http://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
  def symbolize_keys_recursively
    return self.inject({}){|memo,(k,v)| memo[k.to_sym] = v.deep_symbolize_keys; memo} if self.is_a? Hash
    return self.inject([]){|memo,v    | memo           << v.deep_symbolize_keys; memo} if self.is_a? Array
    return self
  end
end