class BGSTag < Tag
  belongs_to :bgs, :class_name => "Bgs", :foreign_key => :foreign_id, :include => [:event,:char,:skill]
end

