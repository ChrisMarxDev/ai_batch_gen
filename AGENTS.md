# Global Instructions / Personal Defaults

## General Coding Guidelines

1. **Ask before assuming**  
   - If a requirement or behavior is ambiguous, do **not** invent your own variant. Ask me (the developer) for clarification before proceeding.  
   - Avoid filling gaps with guesses. Better to get the spec right up front.

2. **Spec & Task Document before Coding**  
   - Before writing any code for a change/feature/bugfix, first produce:  
     1. A **spec document** (describing what must be done, edge cases, input/output, error behavior)  
     2. A **task breakdown document** (a list of subtasks, dependencies, order, time estimates)  
   - Send those to me for review and approval before implementing any code.

3. **Code Quality & Safety Rules**  
   - Always write clear, readable, and maintainable code.  
   - Use meaningful names—don’t abbreviate in confusing ways.  
   - Avoid duplication; follow DRY (Don’t Repeat Yourself).  
   - Don’t introduce new dependencies without strong justification.  
   - Never commit secrets, credentials, or sensitive data into source.  
   - After changes, always run (and pass) linting, static analysis, formatting, and tests before merging.  
   - Keep instructions in this file minimal and focused—don’t overload with rarely used rules.

---

## Flutter-Specific Guidelines  
*(only apply if the project is a Flutter / Dart app)*

1. **Widgets as full classes, not nested functions**  
   - Do **not** create UI by writing deeply nested builder functions or closures inside another widget build.  
   - Always extract into full `StatelessWidget` / `StatefulWidget` (or equivalent) classes, even for smaller sub-components.  
   - This improves readability, testability, and composability.  
   - Prefer one widget per file if it’s nontrivial.

2. **Domain & logic belong in a state controller**  
   - All non-UI / domain logic (state mutations, business rules, transformations) must live in a dedicated state controller: e.g. `Cubit`, `StateNotifier`, `BeaconController`, or another pattern you use.  
   - UI / widget layer should be *purely a function of state*.  
     > **UI = F(state)**  
     Widgets receive state and render accordingly; when user actions happen, they call methods / actions on the state controller.  
   - Avoid placing domain logic inside widgets, UI event handlers, or directly inside `build()` methods.

3. **Separation of concerns & state → UI flow**  
   - Widgets should be passive / declarative: they *display* state, and *invoke actions*.  
   - The state controller coordinates side effects, validations, business logic, transitions.  
   - Keep UI layer “thin” and logic layer “thick”.  
   - Avoid mixing state logic with UI layout or rendering decisions.

---

> *Note:* You can override parts of these defaults in project-level or feature-level instruction files (e.g. local `AGENTS.md`) if a particular project has justified special rules.
