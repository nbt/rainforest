module Kernel
  alias_method :old_require, :require
  @@level = 0

  def require(name)
    puts("=== require #{@@level}: #{name}")
    @@level += 1
    old_require(name)
    @@level -= 1
  end
end
