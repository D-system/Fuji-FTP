
Hash.class_eval do
  def values_not_nil_in_array
    res = []
    self.each_value do |v|
      if not v.nil?
        res << v
      end
    end
    res
  end
end
