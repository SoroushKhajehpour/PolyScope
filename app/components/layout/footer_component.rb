# frozen_string_literal: true

module Layout
  # Renders the site footer with links and credits.
  # Used in the application layout on every page.
  class FooterComponent < ViewComponent::Base
    def footer_links
      [
        { label: "Markets", path: "/" },
        { label: "Disputes", path: "/disputes" },
        { label: "UMA", path: "/uma" },
        { label: "About", path: "/about" }
      ]
    end
  end
end
