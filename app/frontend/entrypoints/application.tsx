import "@/css/globals.css"
import "@/css/animations.css"

import { createInertiaApp } from "@inertiajs/react"
import { createRoot } from "react-dom/client"

const pages = import.meta.glob("../pages/**/*.tsx")

type PageLoader = () => Promise<unknown>

function resolvePageModule(name: string): PageLoader | undefined {
  const exact = `../pages/${name}.tsx`
  let loader = pages[exact as keyof typeof pages] as PageLoader | undefined
  if (!loader) {
    const needle = `pages/${name}.tsx`.replace(/\\/g, "/")
    const key = Object.keys(pages).find((k) =>
      k.replace(/\\/g, "/").endsWith(needle)
    ) as keyof typeof pages | undefined
    loader = key ? (pages[key] as PageLoader) : undefined
  }
  return loader
}

async function boot() {
  await createInertiaApp({
    resolve: async (name) => {
      const importPage = resolvePageModule(name)
      if (!importPage) {
        throw new Error(
          `Page not found: ${name}. Known keys: ${Object.keys(pages).sort().join(", ")}`
        )
      }
      const module = await importPage()
      return module as { default: React.ComponentType }
    },
    setup({ el, App, props }) {
      if (!el) {
        console.error("[PolyScope] Inertia root element #app is missing.")
        return
      }
      createRoot(el).render(<App {...props} />)
    },
  })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => void boot())
} else {
  void boot()
}
