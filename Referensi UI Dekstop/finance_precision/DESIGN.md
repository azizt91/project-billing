---
name: Finance Precision
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daea'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eefe'
  surface-container-high: '#e2e8f8'
  surface-container-highest: '#dce2f3'
  on-surface: '#151c27'
  on-surface-variant: '#4a4452'
  inverse-surface: '#2a313d'
  inverse-on-surface: '#ebf1ff'
  outline: '#7b7483'
  outline-variant: '#ccc3d4'
  surface-tint: '#6f46b9'
  primary: '#340075'
  on-primary: '#ffffff'
  primary-container: '#4c1d95'
  on-primary-container: '#b994ff'
  inverse-primary: '#d3bbff'
  secondary: '#5f5a7c'
  on-secondary: '#ffffff'
  secondary-container: '#dcd5fd'
  on-secondary-container: '#605b7d'
  tertiary: '#252728'
  on-tertiary: '#ffffff'
  tertiary-container: '#3a3d3e'
  on-tertiary-container: '#a6a7a8'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ebdcff'
  primary-fixed-dim: '#d3bbff'
  on-primary-fixed: '#260059'
  on-primary-fixed-variant: '#572ba0'
  secondary-fixed: '#e5deff'
  secondary-fixed-dim: '#c8c2e9'
  on-secondary-fixed: '#1b1735'
  on-secondary-fixed-variant: '#474363'
  tertiary-fixed: '#e1e3e4'
  tertiary-fixed-dim: '#c5c7c8'
  on-tertiary-fixed: '#191c1d'
  on-tertiary-fixed-variant: '#454748'
  background: '#f9f9ff'
  on-background: '#151c27'
  surface-variant: '#dce2f3'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-num:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  sidebar-width: 260px
  container-padding: 2rem
  gutter: 1.5rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 2rem
---

## Brand & Style
The design system focuses on institutional trust, clarity, and fiscal empowerment. Targeted at individual investors and financial managers, the aesthetic prioritizes information density without clutter.

The visual style is **Minimalist / Corporate**, utilizing a card-based architecture to modularize complex data. It avoids unnecessary ornamentation, relying on purposeful whitespace and a disciplined color application to guide the user's eye toward critical financial metrics. The emotional response should be one of control, security, and professional-grade insight.

## Colors
This design system employs a hierarchical color strategy to manage data-heavy environments.
- **Primary (#4C1D95):** Used for key actions, active states in navigation, and branding elements.
- **Secondary (#DDD6FE):** A light purple used for subtle background highlights, progress bar tracks, and hover states.
- **Surface (#F9FAFB):** The primary background color to maintain a clean, "Soft Gray" canvas.
- **Semantic Red (#EF4444):** Reserved exclusively for negative trends, alerts, and critical data points.
- **Semantic Green (#10B981):** Used for positive growth, gains, and successful status indicators.

## Typography
Inter is selected for its exceptional legibility in data-dense interfaces and its neutral, professional character. 

For financial values, always enable **Tabular Numerals** (`tnum`) to ensure numbers align vertically in tables and lists, facilitating easier comparison. Use `display-lg` for primary balances, `headline-md` for card titles, and `label-md` (in all caps) for category headers and metadata.

## Layout & Spacing
The design system utilizes a **Fixed Sidebar / Fluid Content** layout model. 
- **Navigation:** A 260px vertical sidebar remains docked to the left.
- **Grid:** A 12-column fluid grid system for the main content area.
- **Rhythm:** An 8px base scaling unit governs all spacing. Metric cards typically span 3 columns on desktop, while primary charts span 6 to 9 columns.
- **Mobile Adaptivity:** On mobile devices, the sidebar collapses into a bottom navigation bar or a hamburger menu. The 12-column grid reflows to a single column with 1rem side margins.

## Elevation & Depth
Depth is conveyed through **Tonal Layers** and **Ambient Shadows**. 
- **Level 0 (Background):** Soft Gray (#F9FAFB).
- **Level 1 (Cards/Sidebar):** Pure White (#FFFFFF) with a 1px border (#E5E7EB) and a very soft, diffused shadow (0px 4px 6px -1px rgba(0, 0, 0, 0.05)).
- **Level 2 (Dropdowns/Modals):** Pure White with a more pronounced elevation shadow to indicate interaction priority.

Avoid heavy shadows; the goal is to make cards appear slightly lifted from the surface, creating a "stacked paper" effect.

## Shapes
The shape language is "Soft," utilizing conservative radii to maintain a professional, organized feel.
- **Standard Radius:** 0.25rem (4px) for input fields, buttons, and small tags.
- **Large Radius:** 0.5rem (8px) for containers, cards, and modal windows.
- **Icons:** Use 24px stroke-based icons with a 2px weight for consistency with the typography.

## Components
- **Vertical Navigation:** Primary color used for the active state indicator (a left-side 4px border) and icon tint. Unselected items remain Neutral Gray.
- **Metric Cards:** Should feature a `label-md` title, a `display-lg` primary value, and a small "trend chip" (success or error background with 10% opacity) showing percentage change.
- **Buttons:** Primary buttons use the Deep Purple background with White text. Ghost buttons use a 1px border of #E5E7EB with Primary text.
- **Charts:**
    - **Line Charts:** 2px stroke width. Use Primary Purple for the main data line. Use a subtle gradient fill underneath for "Area" variants.
    - **Donut Charts:** 12px stroke thickness for the rings. Use a palette of Primary, Secondary, and Neutral tints to differentiate segments.
- **Input Fields:** 1px border (#D1D5DB) that shifts to Primary Purple on focus. Labels are positioned above the field in `label-md`.
- **Data Tables:** Row-based with subtle dividers. No vertical borders. Header row uses a light gray background (#F3F4F6).