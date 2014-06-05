# encoding: UTF-8

class CDKCategory < Sequel::Model(:categories)
  # TODO:
  #one_to_many :layers

  def self.id_from_name(name)
    category = CDKCategory.dataset.select(:id).where(name: name).first
    if category
      category[:id]
    else
      nil
    end
  end

end

