# Documentation standard

How committed documentation and code comments are written across `branchLeft` repositories.

## Goal

Everything committed reads as a public artefact, whether or not the repo is public yet. A reader arriving with no history — an outside contributor, a future maintainer, you in a year — should be able to learn how the system works without having to reconstruct how it came to work that way.

That reader is the audience for every word in the repo. The development process is not part of what they need.

## Documents describe the current state

Write what is true now. Not what was true, not what was decided when, not what it used to be before someone changed it.

This rules out, in committed documentation:

- **Status headers** — `**Status:** draft`, `**Status:** decided 2026-08-03`. A document that is in the repo is the current description of the thing. If it is wrong, fix it; if it is incomplete, finish it or say what is missing in the prose.
- **Superseded sections** — struck-through text, "previously we...", "originally this was...", "changed from X to Y". Delete the old thing and describe the new one.
- **Dated verification logs** — "verified live 2026-08-04", "confirmed in production on...", "as of <date>". Either the document is accurate, in which case say so plainly, or it isn't, in which case the date doesn't rescue it.
- **Process references** — story or ticket IDs, PR numbers used as narrative ("landed in #42", "see the discussion on #17"), review-round notes, "as we agreed".

None of that information is lost by removing it. It lives in `git log`, in PR descriptions, and in the diff — which is where a reader goes when they specifically want history, and where it doesn't tax the reader who doesn't.

Bare dates are fine where the date is part of the fact rather than a record of the work: a price list, a legal effective date, a pinned upstream release. The test is whether the date would still matter to a reader who had never seen the repo before.

## People are named by role, not by name

Three cases, three treatments.

**Process gating** — "Rob-only", "needs Rob's approval before running". Use the role: *platform owner*, *repo admin*, *operator*. The constraint is real and must survive; the name is an implementation detail of who currently holds the role.

> `Repo visibility is Rob-only per convention` → `Repo visibility is changed by a repo admin`

**Decision attribution** — "Rob asked for...", "per Rob's direction", "Rob's brief was...". Delete the attribution and state the decision, with its reasoning, as a fact about the system. Who asked for something is not a property of the system; why it is that way is.

> `Rob's brief was "each client will need config of some description"` → `Each tenant needs its own configuration, so...`

**Legal and contractual documents** — DPAs, terms, privacy notices, DPIAs. These genuinely need a named accountable party, and inventing a role noun would change what the document asserts. Use an ALL_CAPS placeholder that the executing copy fills in: `[DATA_CONTROLLER_NAME]`, `[PLATFORM_OWNER]`.

Work email addresses on `branchleft.co.uk` are exempt from all of the above. They are role-ish addresses on an already-public domain, and in a runbook the literal value is what the operator needs to type or check against.

## Unverified claims are marked where the claim is made

Some documented positions are researched but not confirmed hands-on. That distinction is load-bearing — a plausible-sounding finding that turns out to be a test artifact will otherwise be built on — so it survives the rule against status headers. It just moves to where it does the most good.

Mark it inline, at the claim, saying what was not confirmed and what would confirm it:

```markdown
> **Unverified.** Derived from the upstream documentation, not confirmed against
> source or a live sandbox. Do not build on this without confirming first.
```

Not a document-level header. A header tells a reader that *something* in a long document is uncertain without telling them what, which is close to useless; and it goes stale silently as the rest of the document is verified around it.

## Placeholders are ALL_CAPS in square brackets

`[TENANT_LEGAL_NAME]`, `[PLATFORM_OWNER_ACCOUNT]`, `[DATE]`. Unmistakable on sight, greppable, and impossible to mistake for a real value that someone forgot to change. This applies to template documents and to any runbook where the operator substitutes a value.

## Links resolve inside the repo

Every relative link must point at a file that exists, inside the same repository. A link to `../BACKLOG.md` may work on the machine where it was written; from a fresh clone it is a dead link, and it advertises the existence of things the reader cannot see.

Relative paths that stay inside the repo are fine and preferred — `../10-compliance.md` from a subdirectory resolves correctly and survives the repo being moved or renamed. For genuine cross-repo references, use an absolute GitHub URL.

## Where a piece of writing belongs

- **README** — what this repo is, and what someone needs to get started. First thing a visitor reads.
- **RUNBOOK** — a procedure an operator executes, in order, usually with commands. One per procedure; name it for the procedure (`RUNBOOK-adding-a-site.md`).
- **`docs/`** — architecture and design: how the system is put together and why it is put together that way.
- **PR description** — why this change, what was considered, what was rejected. The natural home for everything the rules above take out of the repo.

## Code comments

Comments state only what the code cannot: a non-obvious constraint, an invariant, a workaround, a reason the naive approach fails. They do not narrate what the code does, and the rules above apply to them in full — no names, no ticket IDs, no dated verification notes, no decision history.

A comment that needs more than a line or two is usually a document that ended up in the wrong file. Move it to a README or a runbook and leave a one-line pointer. The test: if an operator would ever need to follow it as a procedure, it is a runbook, not a comment.

## Enforcement

The `docs-lint` check in [branchLeft/github-workflows](https://github.com/branchLeft/github-workflows) enforces the mechanical parts of this document — the parts a regex can see. Its rule reference, including the escape hatches and how to use them, lives there alongside the implementation.

The parts it cannot check are the parts that matter most: whether a document actually describes the current state, and whether a comment is earning its place. Those are review judgements, and reviewers should make them.
