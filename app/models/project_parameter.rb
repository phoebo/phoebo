# Project parameter
class ProjectParameter < ActiveRecord::Base
  belongs_to :project_set

  FLAG_SECRET = 0x01

  def secret=(value)
    if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(value)
      self[:flag] |= FLAG_SECRET
    else
      self[:flag] &= ~FLAG_SECRET
    end
  end

  def secret?
    (flag & FLAG_SECRET) > 0
  end
end
