# Practice: what ready means

Read with `SKILL.md`. Mark a unit ready only when all of this holds:

1. **The project's checks pass locally**, all of them, not only the tests of what you touched. Nothing checks a tentative claim for you.
2. **A reviewer that did not write the change has read the whole of it**, as it stands at the last commit, against the item or its design: a reviewer subagent where the session can start one. A later commit that changes the diff gets a review of its own.
3. **Every finding is fixed, filed or dropped.** Where the project also names the `findings` practice, by its rules.
4. **The description says** what changed, how it was tested and that the review ran.
5. **The claim shows exactly the items you claimed.** Run `roadmap` and read the line for your branch, and what it says changed since you last looked.
6. **Nobody is surprised by your files.** Run `roadmap overlap`. Where another claim changes a file yours changes, the description names that claim; whichever of the two lands second takes the default branch in first.
7. **What the project's rules file asks beyond this is done** on the same branch, such as the documents that change with the code.

A change after that takes the unit back to step 2.
