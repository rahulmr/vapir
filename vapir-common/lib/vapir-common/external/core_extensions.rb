class Module
  def alias_deprecated(to, from)
    define_method to do |*args|
      Kernel.warn "DEPRECATION WARNING: #{self.class.name}\##{to} is deprecated. Please use #{self.class.name}\##{from}\n(called from #{caller.map{|c|"\n"+c}})"
      send(from, *args)
    end
  end
end

class String
  if method_defined?(:ord)
    alias vapir_ord ord
  else
    def vapir_ord
      unpack("U*")[0] # assume it's unicode 
    end
  end
end

class Symbol
  def to_proc
    proc{|__x__| __x__.send(self)}
  end
end