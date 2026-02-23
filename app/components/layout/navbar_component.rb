# frozen_string_literal: true

module Layout
  # Renders the top navigation bar with logo and nav links.
  # Used in the application layout on every page.
  class NavbarComponent < ViewComponent::Base
    def nav_links
      [
        { label: "Markets", path: "/" },
        { label: "Disputes", path: "/disputes" },
        { label: "UMA", path: "/uma" },
        { label: "About", path: "/about" }
      ]
    end
  end
end
