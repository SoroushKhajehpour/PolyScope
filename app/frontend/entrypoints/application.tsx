import "@/css/globals.css"
import "@/css/animations.css"

import { createInertiaApp } from "@inertiajs/react"
import { createRoot } from "react-dom/client"

const pages = import.meta.glob("../pages/**/*.tsx")

createInertiaApp({
  resolve: async (name) => {
    const importPage = pages[`../pages/${name}.tsx`]
    if (!importPage) {
      throw new Error(`Page not found: ${name}`)
    }
    const module = await importPage()
    return module as { default: React.ComponentType }
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />)
  },
})
