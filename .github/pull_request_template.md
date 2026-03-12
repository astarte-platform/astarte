#### What this PR does / why we need it:

#### Additional documentation e.g. usage docs, diagrams, reviewer notes, etc.:

<!--
This section can be blank if this pull request does not require additional resources.
-->

---

<details>
<summary><i>Thanks for sending a pull request! If this is your first time, here are some tips for you:</i></summary>

1. You can take a look at our [developer guide] for an introduction on Astarte development!
2. Make sure to read [CONTRIBUTING.md] and [CODE_OF_CONDUCT.md]
3. If the PR is unfinished or you're actively working on it, mark it as draft

When fixing existing issues, use [github's syntax to link your pull request] to it

> `fixes #<issue number>`

We also have a syntax to signal dependencies to other open pull requests

> `depends on #<pr number>`
> `depends on https://github.com/...`

In case of stacked PRs, you may add the PR number in the last commit's title instead:

> ```mermaid
> gitGraph
>     commit id: "Current master"
>     branch feat1
>     checkout feat1
>     commit id: "feat: add something"
>     commit id: "feat: add something else (#100)"
>     branch feat2
>     checkout feat2
>     commit id: "refactor: do something"
>     commit id: "fix: solve issue"
>     commit id: "feat: add a feature (#101)"
>     branch feat3
>     checkout feat3
>     commit id: "feat: feat without pr number"
> ```

</details>

[github's syntax to link your pull request]: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue#about-linked-issues-and-pull-requests
[developer guide]: https://docs.astarte-platform.org/astarte/snapshot/001-dev_guide.html
[CONTRIBUTING.md]: ../CONTRIBUTING.md
[CODE_OF_CONDUCT.md]: ../CODE_OF_CONDUCT.md
