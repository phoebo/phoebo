class Redis
  def self.composite_key(*args)
    args.collect do |arg|
      arg.to_s.gsub(/\\/, '\\\\\\\\').gsub(/\//, '\\\\/')
    end.join('/')
  end
end