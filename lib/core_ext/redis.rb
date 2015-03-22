class Redis
  def self.composite_key(*args)
    args.collect do |arg|
      arg.gsub(/\\/, '\\\\\\\\').gsub(/\//, '\\\\/')
    end.join('/')
  end
end