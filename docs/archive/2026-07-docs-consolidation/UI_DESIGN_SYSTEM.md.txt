# Aarast UI Design System

> Status: legacy high-level design reference.
> Current mobile rebuild design rules live in `docs/mobile-ux/DESIGN_SYSTEM.md`; future visual polish rules live in `docs/mobile-ux/VISUAL_SYSTEM.md`.
> Keep this file short and do not duplicate the rebuild design system here.

## 1. Brand Identity & Vibe
- **Core Feeling**: Calm, Trustworthy, Premium, Clear
- **Cultural Context**: Yemeni wedding traditions, Arabic-first (RTL layout)
- **Target Audience**: Engaged couples (primarily grooms taking on financial planning) and their families.
- **What to Avoid**: Overly flashy decorations, childish illustrations, confusing financial jargon.

## 2. Color Palette
To ensure a premium feel and clear financial visibility, we use a limited color palette.

### Primary Colors
- **Deep Burgundy (Wedding Maroon)**: `#800020` (Use for primary buttons, active tabs, header highlights)
- **Warm Gold**: `#D4AF37` (Use for accents, premium features, subtle borders)
- **Soft Ivory / Warm Off-White**: `#F9F6F0` (App background color, providing a calm atmosphere)

### Text & Neutral Colors
- **Dark Charcoal**: `#333333` (Primary text color for readability)
- **Medium Gray**: `#757575` (Secondary text, descriptions, inactive icons)
- **Light Gray**: `#E0E0E0` (Dividers, disabled states, subtle borders)
- **White**: `#FFFFFF` (Card backgrounds, input field backgrounds)

### Semantic Colors
- **Success (Calm Green)**: `#2E7D32` (Completed tasks, fully paid items, positive balances)
- **Warning (Amber)**: `#FF8F00` (Upcoming due dates, pending payments, warnings)
- **Danger (Red but not aggressive)**: `#D32F2F` (Overdue tasks, missed payments, destructive actions)

## 3. Typography
- **Primary Font**: Cairo or Tajawal (Google Fonts, excellent for modern Arabic interfaces).
- **Direction**: Right-to-Left (RTL) exclusively.

### Typography Scale
- **H1 (Large Headers)**: 24sp, Bold - Screen titles (e.g., Dashboard, Budget)
- **H2 (Section Headers)**: 20sp, Bold - Card titles, important subsections
- **H3 (Subtitles)**: 16sp, Semi-Bold - Form labels, list item titles
- **Body 1 (Primary Text)**: 14sp, Regular - General descriptions, user inputs
- **Body 2 (Secondary Text)**: 12sp, Regular - Timestamps, helper text, small notes

## 4. UI Components

### Buttons
- **Primary Button**: Deep Burgundy background, White text, rounded corners (8dp). Fully opaque.
- **Secondary Button**: White background, Deep Burgundy text and border (1dp).
- **Tertiary/Text Button**: No background, Deep Burgundy text.

### Cards
- **Background**: White `#FFFFFF`.
- **Corner Radius**: 12dp to 16dp for a soft, modern feel.
- **Shadow**: Subtle drop shadow to elevate cards off the ivory background (e.g., `box-shadow: 0 4px 6px rgba(0,0,0,0.05)`).
- **Spacing**: 16dp internal padding.

### Inputs
- **Background**: White or very light gray.
- **Border**: 1dp solid light gray, turning Deep Burgundy on focus.
- **Labels**: Float above the input or stay aligned to the right (RTL).
- **Corner Radius**: 8dp.

### Navigation
- **Bottom Navigation Bar**: White background.
  - Active item: Deep Burgundy icon and text.
  - Inactive item: Medium Gray icon and text.

## 5. Spacing & Layout
- **Base Unit**: 8dp grid system.
- **Screen Padding**: 16dp on left and right edges.
- **Element Spacing**: 8dp (tight), 16dp (standard), 24dp (loose/sections).

## 6. Financial Data Visualization (Future/Notes)
- Progress bars for budget vs. spent: Deep Burgundy (spent) vs Light Gray (remaining). If over budget, use Danger Red.
- Numbers must be clearly legible and use standard Arabic numerals (1, 2, 3 - preferred in modern Yemeni digital interfaces, though Eastern Arabic numerals ٠,١,٢ can be used if requested by users).
