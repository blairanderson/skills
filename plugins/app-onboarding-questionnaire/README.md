# App Onboarding Questionnaire Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install app-onboarding-questionnaire@blairanderson-skills
```

This plugin adds one skill for designing and building a high-converting questionnaire-style onboarding flow.

---

## `/app-onboarding-questionnaire`

Design and build a high-converting onboarding flow for your app, modelled on proven conversion patterns from top subscription apps like Headspace, Noom, and Duolingo.

Walks through the full onboarding design in phases:

1. **Recall** — checks memory for previously saved progress and resumes from the last phase
2. **App Discovery** — reads the codebase to understand what the app does, its core loop, the "aha moment", existing paywall, and required permissions (auto-detected from `Info.plist`, `AndroidManifest.xml`, etc.)
3. **User Transformation** — defines the before/after state the app creates and extracts 3–5 specific, measurable benefit statements
4. **Onboarding Blueprint** — designs the screen-by-screen flow using 14 screen archetypes (Welcome, Goal Question, Pain Points, Social Proof, Tinder Cards, Personalised Solution, Comparison Table, Preference Configuration, Permission Priming, Processing Moment, App Demo, Value Delivery, Account Creation, Paywall)
5. **Screen Content** — drafts headlines, options, CTA copy, and social proof for every screen
6. **Implementation** — builds each screen in the app's framework (SwiftUI, UIKit, React Native, Flutter, Jetpack Compose, etc.) with navigation, progress bar, state persistence, and first-launch detection
