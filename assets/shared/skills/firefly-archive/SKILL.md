---
name: firefly-archive
description: Use when the user explicitly asks firefly to archive one named, active OpenSpec change, after syncing its delta specs into the main spec set.
---

# firefly Archive

Use this skill only when the user explicitly names a change to archive.

## Required Input

- An explicit active change name or change directory.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

- Verify the change exists.
- Verify the change is not already archived.
- Treat the explicit archive command as authorization to sync the named change's delta specs and perform the local archive move; it does not authorize push, release, or history rewriting.
- Independently review the sync plan, sync result, and archive package. Require `APPROVE`, `REVISE`, or `ESCALATE` with evidence.
- Sync the change's delta specs into the main specs by default, then run `"{{PLATFORM_HOME_ENV}}/firefly/bin/firefly" validate --root <project-root>`.
- Repair only issues in the sync result or archive package that are inside the archive authorization envelope, then revalidate and request another independent review.
- For any other validation failure, diagnose it and return `ESCALATE` with evidence instead of editing outside that envelope.
- After each `APPROVE`, continue directly to the next sync or archive action. Only `ESCALATE` may request user input for data-loss risk, a goal conflict, missing authorization, or a real capability failure.
- Do not auto-select or infer the target change.
