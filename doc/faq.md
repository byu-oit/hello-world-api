# Frequently Asked Questions

### Why is CodeDeploy taking forever in `dev`?

Fargate is probably thrashing - tasks aren't coming up healthy.

### Why is CodeDeploy taking so long in `prd`?

By default, the template gives you 15 minutes before destroying the old resources in case you want to roll back.

### What's happening when AfterAllowTestTraffic fails?

For whatever reason, CodeDeploy doesn't link you out to the lambda it executed, but that's the Postman test lambda.

### So I found out my container is thrashing. When I looked at Fargate, I got `ResourceInitializationError: unable to pull secrets`. What's up with that?



### So I found out my container is thrashing. When I looked at Fargate, I see a `CannotPullContainerError`. What's up with that?



### How do I get a pretty URL?



### Where do I see what's happening with my Postman tests?



### Why do my Postman tests get `ENOTFOUND`?



### What do I do with these Dependabot pull requests? Are they safe to merge if they pass CI?

It depends. Dependabot's great at letting us know that a dependency has a newer version. It also usually makes it pretty easy for you to update it - or at least, it gives you a starting point.

What would we have done, beforehand, when updating a dependency? You know, before we had a Dependabot pull request? Typically, we'd look at the new semantic version to give us a broad sense of if it contains potentially-breaking changes. Major version updates indicate breaking changes. Then, we'd check out patch notes to see if we were affected. Conveniently, the PR tells us the new version and typically provides the changelog.

The fact that tests can run on PRs is convenient, but those ✔s are only as good as our tests. If we have a PR to update `standard`, the linter, and we see that the lint step in CI passes, that's a pretty safe merge. If we're updating an HTTP request library, unit tests in CI don't tell us much because we're probably stubbing that library out. We'd need integration tests for that.
