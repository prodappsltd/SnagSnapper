# SnagSnapper Development Notes

## Project Overview

SnagSnapper is a Flutter app for construction site snag management. Users can track sites, document snags (defects/issues) with photos, assign work to collaborators, and generate PDF reports.

### Key Features
- **Site Management**: Track multiple construction sites with sharing capabilities
- **Snag Documentation**: Issues with up to 6 problem photos + 6 fix photos per snag
- **Collaboration**: Share sites with VIEW, WORKING, or CONTRIBUTOR permissions
- **PDF Reports**: Professional snag reports with company branding
- **Firebase Integration**: Auth, Firestore, Storage, Cloud Functions, Crashlytics

### Technical Stack
- **Frontend**: Flutter/Dart (Material 3)
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions, Crashlytics)
- **Database**: SQLite (drift) for local data storage
- **Security**: Firebase App Check, freeRASP for RASP protection
- **Key Packages**: provider, image_picker, firebase_*, drift

---

## RULES

## Rule #1: Code Quality & Documentation Standards
- Always read and update documentation alongside code changes
- Maintain clear README files and inline documentation
- Document architectural decisions and design patterns
- **Always add extensive comments to code when making changes, however minor they are**
- Always add extensive comments and reasoning behind decisions for functions and code in general
- **Always run `flutter analyze` before indicating task complete**
- **Try to keep lint errors to minimum**

## Rule #2: Communication & Decision Authority
- Be specific about requirements - avoid ambiguity
- State exact file paths, function names, and expected outputs
- Use CLAUDE.md for rules to define project standards
- State what you're doing and why
- Explain non-obvious decisions
- Ask for clarification when requirements are unclear
- **If you do not know something, say you do not know - Critical!**
- AI suggestions must be reviewed before implementation
- Question unclear or risky changes
- **User is the final decision maker**
- **You can provide opinions for consideration and do not have to agree with user proposals, but must follow user decisions - Very important!**
- **Always propose the option you believe is best with clear reasoning - do not just agree with user suggestions. Honest technical assessment is more valuable than agreement.**

## Rule #3: Development Process & Review
- Always analyze existing code patterns before making changes
- Check imports, dependencies, and neighboring files
- Follow established conventions in the codebase
- Break complex tasks into smaller, testable steps
- Review and test after each significant change
- Avoid accumulating technical debt
- Consider performance implications of changes
- Avoid unnecessary iterations or computations
- Profile and optimize when needed
- **After implementing a change, always review it before moving to next change - Very important!**

## Rule #4: Functional Over Complex
- **Always start with simple fix first - Very important!**
- Prefer functional and declarative patterns
- Avoid unnecessary complexity
- Keep functions small and focused

## Rule #5: Error Handling & Logging
- Use guard clauses and early returns
- Handle edge cases at the beginning of functions
- Provide clear, actionable error messages
- Add guarded debug logging for development, use Crashlytics for production
- Use breadcrumbs for error tracking

## Rule #6: Testing Requirements
- Write tests for all new functionality
- Run existing tests before making changes
- Ensure all tests pass before considering task complete

## Rule #7: File & Dependency Management
- **Never assume libraries or frameworks are available - Check pubspec.yaml first**
- Verify file existence before operations
- Always prefer editing existing files
- Only create new files when absolutely necessary
- Never create documentation unless explicitly requested
- Always use the latest stable versions from pub.dev
- Check pub.dev before adding or updating any dependency
- Use caret syntax (^) for semantic versioning
- Document why if using older version for compatibility
- **Never add external dependencies without prior approval**
- **Provide justification, dependency reputation and reliability assessment**
- **Only dependencies from reputable developers should be considered**
- **Always get explicit approval before adding any new dependencies**

## Rule #8: Security & Privacy
- Never commit secrets, keys, or credentials
- Validate all inputs
- Follow OWASP guidelines for web applications

## Rule #9: Version Control Discipline
- Make atomic, focused commits
- Write clear commit messages
- Never push directly to main/master without review **and explicit permission**

## Rule #10: Code Change Approval Process (CRITICAL)

**NEVER implement code changes without following this process:**

### Phase 1: High-Level Proposal (REQUIRED BEFORE ANY CODE)
Present a comprehensive proposal including:

1. **Rationale**: Why this change is needed
2. **Impact Assessment**:
   - What components/files will be affected
   - Performance implications
   - User-facing changes
   - Breaking changes (if any)
3. **Implementation Plan**:
   - Step-by-step approach
   - Files to be modified
   - New dependencies (if any)
4. **Risk Rating**: LOW / MEDIUM / HIGH / CRITICAL
   - Potential bugs or edge cases
   - Rollback strategy
   - Testing requirements

**Important**: Avoid showing long code blocks in proposals. Include all critical information but keep it concise.

### Phase 2: Iterative Review & Bug Assessment
- Describe code changes concisely - avoid showing long code blocks unnecessarily
- Focus on explaining what will change and why, not the full implementation
- Conduct iterative bug review cycles
- Continue reviews until last 3 consecutive reviews find no new issues
- Document all findings and resolutions when explicitly requested

**Important**: Long code blocks in Phase 2 proposals increase console scrolling without adding value. Describe changes clearly but concisely.

### Phase 3: Final Approval
- Wait for explicit user approval before implementing
- Never assume approval - always wait for confirmation
- User will respond with "approved" or request modifications

**Violation of this rule is unacceptable and wastes time**

---

## Risk Assessment (Site_Sharing_RA.html)

### Validation Rules
- **Every codebase location MUST show "Verified"** - Confirmed against actual code, no assumptions
- Line numbers must be verified against actual code
- If code changes, line numbers must be updated
- Decision documents should reference RA item numbers

### When Editing RA
- **PRESERVE dropdown selection states** (`selected="selected"` and inline styles)
- User marks items as Tested/N/A/Accept manually after verification
- Do not overwrite user's selections when updating other fields

### Dropdown Options
- **Tested** (green) - Verified working
- **N/A** (orange) - Not applicable
- **Accept** (blue) - Risk accepted

## Key Files
- `Risk-Assessment/Site_Sharing_RA.html` - Main RA document
- `Claude/02-MODULES/Sites/SHARING_AND_CF_DECISIONS.md` - Decision log (references RA items)
- `Claude/00-CORE/SHARING_ARCHITECTURE.md` - Architecture documentation
- `Claude/00-CORE/CLOUD_FUNCTIONS_BEST_PRACTICES.md` - **CRITICAL: CF retry, idempotency, error handling**

---

## Cloud Functions Risk Assessment (CRITICAL)

**ALL Risk Assessments involving Cloud Functions MUST reference:**
`Claude/00-CORE/CLOUD_FUNCTIONS_BEST_PRACTICES.md`

### Key Points (from official Firebase/Google Cloud docs):
- **Retry is NOT automatic** - must enable with `retry: true`
- **Without retry**: failed events are **dropped permanently**
- **With retry**: events retry for up to 24 hours (2nd gen)
- **Requirements before enabling retry**:
  1. Function must be idempotent
  2. Event age check must be implemented
  3. Transient vs permanent errors must be distinguished
  4. Must test thoroughly WITHOUT retry first

### Standard CF RA Items
| Item | Description |
|------|-------------|
| Retry Configuration | Is `retry: true` enabled? Justified? |
| Idempotency | Are all operations safe to repeat? |
| Event Age Check | Are stale events discarded? |
| Error Handling | Transient vs permanent errors distinguished? |
| Partial Failure | What if some operations succeed, others fail? |
| Timeout | Can function complete within timeout limit? |
| Recovery | How do users recover from CF failure? |

