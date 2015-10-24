class PlayerTag < Tag
  belongs_to :player, :class_name => "Player", :foreign_key => :foreign_id

  def self.allTags()
    tags = {}
    PlayerTag.find_by_sql("select foreign_id,group_concat(tag separator ',') as taglist from tags where type='PlayerTag' group by foreign_id order by tag").each {|pt| tags[pt.foreign_id] = pt.taglist.split(",") }
    return tags
  end
end
