---
title:  "Git: Revert & Rebase"
layout: post
tags: git
---

# {{ page.title }}

## Rebasing

The best resource to learn what rebasing is, is probably the reading the [Pro
Git book][pro_git_book] and more particularly the ["Rebasing"
chapter][pro_git_rebase].

But, to sum up that concept, we can say that it is the process to rewind from
one commit __C1__ to another one __C2__ and to apply those commit on top of
third one __C3__.

So for example, if we have this git history:

```sh
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* 73f06e9 (HEAD -> main) m7
* 0bd5d4b m6
| * 5d274d4 (topic) m5
| * f1d44ed m4
|/
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

If we want to rebase the branch `topic` on top of the `main` branch, we can use
the rebase command as follows:

```sh
git rebase --onto main fc106f3 topic
```

What this command says: "From the tip of the branch `topic` rewind to the
common ancestor (commit `fc106f3`) and re-apply those commit on top of the
`main` branch".

As a result, the resulting graph will be:

```sh
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* 51c879d (HEAD -> topic) m5
* bdcdd17 m4
* 73f06e9 (main) m7
* 0bd5d4b m6
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

We can see what git did behind the scene:

```sh
% git reflog
45a1e51 (HEAD -> topic) HEAD@{0}: rebase (finish): returning to refs/heads/topic
45a1e51 (HEAD -> topic) HEAD@{1}: rebase (pick): m5
71d9bf3 HEAD@{2}: rebase (pick): m4
73f06e9 (main) HEAD@{3}: rebase (start): checkout main
73f06e9 (main) HEAD@{4}: checkout: moving from topic to main
```

Starting from `main`, the commits whose messages are "m4' and "m5" are applied
successively on top of main.

Of course the command for such a simple rebase is a bit too verbose and git has
some defaults that allow to simply write when you are currently on the `topic`
branch:

```sh
git rebase main
```

Behind the scene, it will act as if you wrote:

```sh
git rebase --onto main $(git merge-base main topic) topic
```

## Revert

Reverting allows you to create a commit that revert a set of commits. It is not
the same as `reset` which moves a HEAD to a specified commit. You will
generally use `reset` locally changes that are not on a public repository.

A classic scenario in which you will want to use `revert`, is when you merged a
topic branch on the `main` one and you are reported with some bugs and as it
would be too long to correctly fix them, you decide to revert your changes.

So once again, starting from the following state:

```sh
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* d0ec91a (topic) m5
* f1d44ed m4
| * 73f06e9 (HEAD -> main) m7
| * 0bd5d4b m6
|/
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

We merge and we also add a new commit on top of `main` because before you
discovered you introduced a bug, someone also pushed a commit (or merged
another topic branch).

```sh
% git merge topic
% git commit --allow-empty -m "m8"
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* 3a0709f m8
*   53759e6 Merge branch 'topic'
|\
| * d0ec91a (topic) m5
| * f1d44ed m4
* | 73f06e9 m7
* | 0bd5d4b m6
|/
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

Now you revert the changes introduced by your `topic` branch merge:

```sh
% git revert -m1 53759e6
[...]

% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* 18744ff (HEAD -> main) Revert "Merge branch 'topic'"
* 3a0709f m8
*   53759e6 Merge branch 'topic'
|\
| * d0ec91a (topic) m5
| * f1d44ed m4
* | 73f06e9 m7
* | 0bd5d4b m6
|/
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

That's good, the other developers (or users if your changes reached the
production) are no more impacted with the bug you introduced.

Now you may want to take you local `topic` branch and fix the bug before
merging again. But, you want to restart working on that branch with the latest
commits that were applied on `main`. So you tell yourself, let's rebase.

But something strange occurred: you lost all your changes. Actually, it is like
a fast-forward occurred:

```sh
% git checkout topic
% git rebase main
Successfully rebased and updated refs/heads/topic.
% git reflog
18744ff (HEAD -> topic, main) HEAD@{0}: rebase (finish): returning to refs/heads/topic
18744ff (HEAD -> topic, main) HEAD@{1}: rebase (start): checkout main
[...]
```

The man page warned us:

> Reverting a merge commit declares that you will never want the
> tree changes brought in by the merge. As a result, later merges
> will only bring in tree changes introduced by
> commits that are not ancestors of the previously reverted merge.
> This may or may not be what you want.

More information can also be found [there][git_revert_a_faulty_merge].

So how to proceed to update out `topic` branch? Well let's express in words
what we want to achieve: we want the commit brought in by our topic branch on
top of the `main` branch. So we want to rewind from the tip of `topic` down to
`fc106f3` and apply that onto `main`. In git parlance:

```sh
% git rebase --onto main fc106f3 topic
Successfully rebased and updated refs/heads/topic.
```

That time, we are good: the two commits of our `topic` branch are applied on
top of `main` and at the end of the operation, the `topic` branch points to the
new rebased commit whose message is "m5":

```sh
% git reflog
871bfec HEAD@{0}: rebase (finish): returning to refs/heads/topic
871bfec HEAD@{1}: rebase (pick): m5
1e33449 HEAD@{2}: rebase (pick): m4
18744ff HEAD@{3}: rebase (start): checkout main
[...]
```

## Bonus Tip: Undoing a Local Rebase

In git, everything that you do is generally reversible (except if you
explicitly use options that sounds dangerous to like `--force` or `--hard`).

In case you are not happy with a rebase, you can easily come back to the state
before the rebase completed. For example, from this state which followed a
rebase:

```sh
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* b905647 (HEAD -> topic) m5
* b371737 m4
* 73f06e9 (main) m7
* 0bd5d4b m6
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
```

If you want to cancel that rebase, you can have a look at the reflog and find
the pointer the where the `HEAD` was before.

```sh
% git reflog
b905647 (HEAD -> topic) HEAD@{0}: rebase (finish): returning to refs/heads/topic
b905647 (HEAD -> topic) HEAD@{1}: rebase (pick): m5
b371737 HEAD@{2}: rebase (pick): m4
73f06e9 (main) HEAD@{3}: rebase (start): checkout main
d0ec91a HEAD@{4}: checkout: moving from main to topic
[...]
```

To move back to the state before the rebase, you can move HEAD to where it was
prior to the rebase: in this case, you can reset to `HEAD@{4}` using the
`--hard` option to have a clean worktree.

```sh
% git reset --hard HEAD@{4}
HEAD is now at d0ec91a m5
% git log --pretty=oneline --graph --decorate --branches --remotes --tags --abbrev-commit
* d0ec91a (HEAD -> topic) m5
* f1d44ed m4
| * 73f06e9 (main) m7
| * 0bd5d4b m6
|/
* fc106f3 m3
* 7ac2078 m2
* 71eb869 m1
% git st
On branch topic
nothing to commit, working tree clean
```

[pro_git_book]: https://git-scm.com/book/en/v2
[pro_git_rebase]: https://git-scm.com/book/en/v2/Git-Branching-Rebasing
[git_revert_a_faulty_merge]: https://github.com/git/git/blob/master/Documentation/howto/revert-a-faulty-merge.txt
