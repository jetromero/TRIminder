/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#fdf2f4',
          100: '#fce4e8',
          200: '#f9c8d1',
          300: '#f5a3b3',
          400: '#ed6d87',
          500: '#c91f4a',
          600: '#a8163c',
          700: '#8b1538',
          800: '#761632',
          900: '#5c122a',
        },
        accent: {
          50: '#fdf9ed',
          100: '#f9efd0',
          200: '#f3dda0',
          300: '#ebc76a',
          400: '#e4b042',
          500: '#d4a84b',
          600: '#b8862a',
          700: '#966524',
          800: '#7a5123',
          900: '#654321',
        },
      },
    },
  },
  plugins: [],
}

