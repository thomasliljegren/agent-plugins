# Practice: the session that claimed a unit merges it

Read with `SKILL.md`. Without this practice merging stays with the owner.

1. **Only what you claimed in this session.** Never another session's unit.
2. **Only when it is ready.** Where the project also names the `ready` practice, by its list.
3. **Only on checks that ran on what is there now.** After you mark the unit ready, wait until every required check belongs to the new run before you set the unit to merge once they pass. A check left over from the tentative claim is no pass.
4. **Watch it until it has merged.** A unit that is still open a few minutes after its required checks passed is merged directly; that is no merge past a failed check.
5. **A change takes merging back off.** As soon as you decide to change the unit (a fix for a failed check, a merge of the default branch, anything else), turn merging on its own off first. Turn it on again once a reviewer has read the change and every finding is fixed, filed or dropped; a merge of the default branch without conflicts needs no review.
6. **Stop and tell the owner** when a run that should have started has not appeared after one retry, or a run was cancelled twice.

The owner's, always: anything that rewrites shared history, and a merge past a failed check.

The method is squash unless the project's rules file names another.
