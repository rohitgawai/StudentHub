---
name: Academic Pulse
colors:
  surface: '#fbf9f9'
  surface-dim: '#dbdad9'
  surface-bright: '#fbf9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#e9e8e7'
  surface-container-highest: '#e3e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#404752'
  inverse-surface: '#303031'
  inverse-on-surface: '#f2f0f0'
  outline: '#707883'
  outline-variant: '#bfc7d4'
  surface-tint: '#0061a4'
  primary: '#0061a4'
  on-primary: '#ffffff'
  primary-container: '#2196f3'
  on-primary-container: '#002c4f'
  inverse-primary: '#9ecaff'
  secondary: '#8b5000'
  on-secondary: '#ffffff'
  secondary-container: '#ff9800'
  on-secondary-container: '#653900'
  tertiary: '#9a25ae'
  on-tertiary: '#ffffff'
  tertiary-container: '#d661e7'
  on-tertiary-container: '#4e005b'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d1e4ff'
  primary-fixed-dim: '#9ecaff'
  on-primary-fixed: '#001d36'
  on-primary-fixed-variant: '#00497d'
  secondary-fixed: '#ffdcbe'
  secondary-fixed-dim: '#ffb870'
  on-secondary-fixed: '#2c1600'
  on-secondary-fixed-variant: '#693c00'
  tertiary-fixed: '#ffd6fe'
  tertiary-fixed-dim: '#f9abff'
  on-tertiary-fixed: '#35003f'
  on-tertiary-fixed-variant: '#7b008f'
  background: '#fbf9f9'
  on-background: '#1b1c1c'
  surface-variant: '#e3e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  title-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
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
  label-lg:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 16px
  container-padding-desktop: 24px
  stack-gap-sm: 12px
  stack-gap-md: 20px
  grid-gutter: 16px
---

## Brand & Style

This design system is built for a vibrant, mobile-first digital campus environment. It bridges the structured organization of a productivity tool like Notion with the high-engagement, content-forward feel of Instagram. 

The design style is **Corporate / Modern** with a focus on **Tonal Layers**. It prioritizes clarity and information density without feeling cluttered. The interface should feel intentional, reliable, and energetic, encouraging students to transition seamlessly from checking grades to browsing campus events. Whitespace is used generously to separate distinct content streams, while high-saturation accents provide immediate visual cues for content categorization.

## Colors

The color palette is functionally driven to provide instant context to the user. 

- **Primary (Blue - #2196F3):** Used for academic core functions, faculty announcements, and primary navigation actions.
- **Secondary (Orange - #FF9800):** Reserved for social engagement, clubs, and coordinator-led event posts.
- **Tertiary (Purple - #9C27B0):** Dedicated to gamification elements, student achievements, and "Spotlight" milestones.
- **Error (Red - #F44336):** Strictly for urgent alerts, campus emergencies, or critical deadline warnings.
- **Success (Green - #4CAF50):** Used for confirmation states, grade improvements, and task completions.
- **Neutral (Grey - #757575):** Applied to secondary information, timestamps, and general administrative metadata.

Backgrounds should utilize a subtle off-white (`#F8F9FA`) to allow the white surfaces of cards to pop visually.

## Typography

The system uses **Inter** for its exceptional readability on mobile screens and its neutral, modern aesthetic. 

- **Headlines:** Use Bold weights with slight negative letter-spacing to create a "compact" feel similar to editorial layouts.
- **Body:** Standardized at 16px for primary reading to ensure accessibility on mobile devices.
- **Labels:** Utilized for Status Badges (Student, Faculty, etc.) and should always be displayed in uppercase with increased letter-spacing to improve scanability at small sizes.

## Layout & Spacing

The design system employs a **Fluid Grid** model optimized for touch-first interaction. 

- **Mobile (Default):** 4-column grid with 16px margins and 16px gutters.
- **Tablet/Desktop:** 12-column grid with a maximum content width of 1200px.
- **Touch Targets:** All interactive elements (buttons, links, chips) must maintain a minimum height of 48px to ensure ease of use during transit or quick interactions.
- **Vertical Rhythm:** A base-8 spacing scale is used. Group related content with 12px (sm) gaps and separate distinct sections with 20px (md) or 32px (lg) gaps.

## Elevation & Depth

This design system uses **Tonal Layers** combined with **Ambient Shadows** to create a structured sense of depth.

- **Level 0 (Base):** The main background (`#F8F9FA`). No shadow.
- **Level 1 (Cards/Surface):** White surfaces used for content feed items. Features a soft, highly-diffused shadow: `box-shadow: 0px 4px 20px rgba(0, 0, 0, 0.05)`.
- **Level 2 (Modals/Overlays):** Used for bottom sheets and pop-ups. Features a more pronounced shadow: `box-shadow: 0px 8px 30px rgba(0, 0, 0, 0.12)`.

To maintain the "Notion-like" clarity, avoid heavy gradients. Use subtle 1px inner borders (`#EEEEEE`) on cards to define edges when shadows are disabled in high-contrast or battery-saver modes.

## Shapes

The shape language is friendly and approachable, defined by **Rounded** geometries.

- **Content Cards:** Must use a 24px corner radius (`rounded-xl` in this system) to create a distinct, soft container that differentiates feed items.
- **Buttons & Chips:** Use a pill-shaped (fully rounded) approach for buttons to maximize the "friendly" aesthetic and make them stand out from the rectangular card containers.
- **Input Fields:** Use 12px corner radius to balance the sharp text with the rounded environment.

## Components

### Status Badges (User Roles)
Badges are critical for identifying authority. They use a light background (10% opacity of the role color) and dark text (full saturation) of the same color.
- **Student:** Grey (#757575)
- **Faculty:** Blue (#2196F3)
- **Event Host:** Orange (#FF9800)
- **Admin:** Purple (#9C27B0)

### Buttons
- **Primary:** High-elevation, pill-shaped, using Primary Blue with white text.
- **Secondary:** Outlined with a 2px stroke of the Primary Blue.
- **Floating Action Button (FAB):** Crucial for the Instagram-inspired "Post" action. Positioned bottom-right with a Tertiary Purple background.

### Cards
Cards are the primary container for the "Hub" feed. Every card should have a 24px corner radius. The header of the card should feature the User Role badge and a timestamp.

### Input Fields
Filled style (Material 3) with a 12px top-rounded corner and a prominent 2px bottom stroke upon focus. This provides a "Notion" feel of structured data entry.

### Lists
Lists should be "Inset" with 16px horizontal padding. Each list item is separated by a subtle divider (`#F0F0F0`) that does not extend to the edges of the screen.