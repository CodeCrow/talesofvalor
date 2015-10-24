class CharTag < Tag
  belongs_to :char, :class_name => "Char", :foreign_key => :foreign_id, :include => :player

  def self.allTags()
    tags = {}
    CharTag.find_by_sql("select foreign_id,group_concat(tag separator ',') as taglist from tags where type='CharTag' group by foreign_id order by tag").each {|ct| tags[ct.foreign_id] = ct.taglist.split(",") }
    return tags
  end
end
