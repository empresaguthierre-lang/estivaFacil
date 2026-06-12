class StowagePlan < ApplicationRecord
  belongs_to :company
  belongs_to :cargo
  belongs_to :vehicle

  enum :status, { sugerido: 0, revisado: 1, aprovado: 2 }

  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def warning_list
    warnings.to_s.lines.map(&:strip).compact_blank
  end

  def recommendation_list
    recommendations.to_s.lines.map(&:strip).compact_blank
  end
end
