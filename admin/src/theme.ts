import { createTheme } from '@mantine/core'

// Cairo is loaded via index.html. Bundling the font file is a later refinement
// (see CLAUDE.md → Language & direction), but the family is wired up here.
export const theme = createTheme({
  fontFamily: 'Cairo, system-ui, sans-serif',
  headings: { fontFamily: 'Cairo, system-ui, sans-serif' },
  primaryColor: 'indigo',
  defaultRadius: 'md',
})
