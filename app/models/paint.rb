class Paint < ActiveRecord::Base
  attr_accessible :name,
    :color_id,
    :manufacturer_id

  validates_presence_of :name 
  validates_uniqueness_of :name
  belongs_to :color 
  belongs_to :manufacturer
  has_many :bikes

  scope :official, where("manufacturer_id IS NOT NULL")

  before_save { |p| p.name = p.name.downcase.strip }

  
  def self.fuzzy_name_find(n)
    if !n.blank?
      self.find(:first, :conditions => [ "lower(name) = ?", n.downcase.strip ])
    else
      nil
    end
  end


end
