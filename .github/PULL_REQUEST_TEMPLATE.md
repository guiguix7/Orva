## Summary
[Describe the user-visible outcome.]

## Priority and specification
- Roadmap priority:
- Relevant specification:
- Acceptance criteria addressed:

## Implementation
- [ ] Existing source-of-truth records reused
- [ ] No duplicate activity/scheduling store introduced
- [ ] Domain logic is deterministic and testable
- [ ] Loading/empty/error/partial states handled
- [ ] UI copy is pt-BR

## Data, migration, and privacy
- Schema changed? [Yes/No]
- Migration tests:
- Backup compatibility:
- Sensitive data exposed to widgets/logs/notifications? [Must be No unless explicitly approved]
- Local-first behavior preserved? [Yes/No]

## Validation evidence
| Check | Result | Notes |
|---|---|---|
| dart format . | PASS / FAIL / NOT RUN | |
| flutter analyze | PASS / FAIL / NOT RUN | |
| flutter test | PASS / FAIL / NOT RUN | |
| flutter build apk --debug | PASS / FAIL / NOT RUN | |
| Emulator/device tests | PASS / FAIL / NOT RUN | |

## Risks and limitations
[State unverified behavior and known gaps.]

## Reviewer checklist
- [ ] No user changes overwritten
- [ ] No destructive migration
- [ ] No duplicate records/rewards
- [ ] No misleading metric or missing-data assumption
- [ ] Docs and CURRENT_STATE.md updated when needed
