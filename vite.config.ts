import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import tailwindcss from "@tailwindcss/vite"
import ViteRails from "vite-plugin-rails"
import { resolve } from "path"

export default defineConfig({
  plugins: [
    ViteRails(),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      "@": resolve(__dirname, "app/frontend"),
    },
  },
})
