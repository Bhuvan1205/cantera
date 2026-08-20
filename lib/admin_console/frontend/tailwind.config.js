/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Brand & Primary — Aligned with Canteen Organic Green (#3A7D5E / #0F382B)
        primary: "#3A7D5E",
        "primary-container": "#2E644A",
        "primary-fixed": "#D6E8DF",
        "primary-fixed-dim": "#A7CCA8",
        "on-primary": "#ffffff",
        "on-primary-container": "#D6E8DF",
        "on-primary-fixed": "#0B271B",
        "on-primary-fixed-variant": "#1F4E38",
        "inverse-primary": "#7BBF9A",

        // Secondary — Aligned with Clay Accent (#5B3F2B)
        secondary: "#5B3F2B",
        "secondary-container": "#F2EBE0",
        "secondary-fixed": "#E8DDD0",
        "secondary-fixed-dim": "#D6C6B4",
        "on-secondary": "#ffffff",
        "on-secondary-container": "#3D2A1D",
        "on-secondary-fixed": "#25180F",
        "on-secondary-fixed-variant": "#4A3527",

        // Tertiary — Deep Forest Green (#0F382B)
        tertiary: "#0F382B",
        "tertiary-container": "#D4E7DC",
        "tertiary-fixed": "#C0DEC8",
        "tertiary-fixed-dim": "#99C8A6",
        "on-tertiary": "#ffffff",
        "on-tertiary-container": "#0B291F",
        "on-tertiary-fixed": "#061A13",
        "on-tertiary-fixed-variant": "#144232",

        // Surface & Background — Warm Ivory & Parchment (#F9F5EF / #FFFDF9)
        background: "#F9F5EF",
        surface: "#F9F5EF",
        "surface-bright": "#FFFDF9",
        "surface-dim": "#F2ECE2",
        "surface-tint": "#3A7D5E",
        "surface-container-lowest": "#FFFDF9",
        "surface-container-low": "#F4EEE4",
        "surface-container": "#ECE4D8",
        "surface-container-high": "#E4DBCF",
        "surface-container-highest": "#DDD3C4",

        // On-Surface (Typography)
        "on-background": "#12251D",
        "on-surface": "#12251D",
        "on-surface-variant": "#5A6660",

        // Outlines & Borders
        outline: "#8C9B92",
        "outline-variant": "#E2DED6",

        // Inverse Surfaces (Sidebar / Dark Elements)
        "inverse-surface": "#0F382B",
        "inverse-on-surface": "#F9F5EF",

        // Semantic Errors & Warnings
        error: "#C94A4A",
        "error-container": "#FCECEC",
        "on-error": "#ffffff",
        "on-error-container": "#7A1C1C",
      },
      spacing: {
        "grid-gutter": "16px",
        sm: "8px",
        base: "4px",
        "table-cell-padding": "12px 16px",
        xl: "32px",
        xs: "4px",
        "sidebar-width": "240px",
        md: "16px",
        lg: "24px",
      },
      fontFamily: {
        "data-mono": ['"JetBrains Mono"', "monospace"],
        "label-caps": ["Inter", "sans-serif"],
        "title-sm": ["Inter", "sans-serif"],
        "body-md": ["Inter", "sans-serif"],
        "body-sm": ["Inter", "sans-serif"],
        "headline-md": ["Inter", "sans-serif"],
        "display-lg": ["Inter", "sans-serif"],
      },
      fontSize: {
        "data-mono": ["13px", { lineHeight: "18px", fontWeight: "400" }],
        "label-caps": ["11px", { lineHeight: "16px", letterSpacing: "0.05em", fontWeight: "700" }],
        "title-sm": ["18px", { lineHeight: "24px", fontWeight: "600" }],
        "body-md": ["14px", { lineHeight: "20px", fontWeight: "400" }],
        "body-sm": ["13px", { lineHeight: "18px", fontWeight: "400" }],
        "headline-md": ["24px", { lineHeight: "32px", letterSpacing: "-0.01em", fontWeight: "600" }],
        "display-lg": ["30px", { lineHeight: "38px", letterSpacing: "-0.02em", fontWeight: "700" }],
      },
    },
  },
  plugins: [],
};
