# frozen_string_literal: true

# Detects resolution criteria changes between two text versions.
# Returns edit_ratio (0-1), magnitude (minor/moderate/major/critical), and change_type for snapshots.
class DescriptionChangeDetector
  MAGNITUDES = %w[minor moderate major critical].freeze

  class << self
    # @param prev_text [String] previous resolution criteria text
    # @param new_text [String] current resolution criteria text
    # @return [Hash] { change_type:, edit_ratio:, magnitude: }
    def detect(prev_text, new_text)
      prev = prev_text.to_s
      curr = new_text.to_s

      edit_ratio = compute_edit_ratio(prev, curr)
      magnitude = classify_magnitude(edit_ratio)

      {
        change_type: magnitude,
        edit_ratio: edit_ratio.round(4),
        magnitude: magnitude
      }
    end

    private

    def compute_edit_ratio(prev, curr)
      return 0.0 if prev == curr
      max_len = [prev.length, curr.length].max
      return 0.0 if max_len.zero?

      distance = levenshtein_distance(prev, curr)
      (distance.to_f / max_len).clamp(0.0, 1.0)
    end

    def levenshtein_distance(a, b)
      n = a.length
      m = b.length
      return m if n.zero?
      return n if m.zero?

      # Two rows only (current and previous)
      curr = (0..m).to_a
      (1..n).each do |i|
        prev = curr.dup
        curr[0] = i
        (1..m).each do |j|
          cost = a[i - 1] == b[j - 1] ? 0 : 1
          curr[j] = [prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost].min
        end
      end
      curr[m]
    end

    # >30% → major/critical, 10–30% → moderate, <10% → minor
    # Split major/critical at 60% for severity.
    def classify_magnitude(edit_ratio)
      case edit_ratio
      when 0.0...0.10 then "minor"
      when 0.10...0.30 then "moderate"
      when 0.30...0.60 then "major"
      else "critical"
      end
    end
  end
end
