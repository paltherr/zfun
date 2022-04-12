# Releasing a new version

These notes reflect the current process.

## Update CHANGELOG.md

Move the content of the unreleased entry to a new `<X.Y.Z>` entry at
the top of [CHANGELOG.md], where `<X.Y.Z>` is the new version number.

Commit the changes in a commit with the message `ZFun <X.Y.Z>`.

[CHANGELOG.md]: https://github.com/paltherr/zfun/blob/main/CHANGELOG.md

## Create a tag

Create a new annotated tag with:

```bash
$ git tag -a v<X.Y.Z>
```

Include the [CHANGELOG.md] notes corresponding to the new version as
the tag annotation, except the first line should be: `ZFun <X.Y.Z> -
YYYY-MM-DD` and any Markdown headings should become plain text, e.g.:

```md
### Added
```

should become:

```md
Added:
```

## Create a GitHub release

Push the new version commit and tag to GitHub via the following:

```bash
$ git push --follow-tags
```

Then visit https://github.com/paltherr/zfun/releases, and:

* Click **Draft a new release**.
* Select the new version tag.
* Name the release: `ZFun <X.Y.Z>`.
* Paste the same notes from the version tag annotation as the
  description, except change the first line to read: `Released:
  YYYY-MM-DD`.
* Click **Publish release**.

For more on `git push --follow-tags`, see:

* [git push --follow-tags in the online manual][ft-man]
* [Stack Overflow: How to push a tag to a remote repository using Git?][ft-so]

[ft-man]: https://git-scm.com/docs/git-push#git-push---follow-tags
[ft-so]: https://stackoverflow.com/a/26438076

## Homebrew

The basic instructions are in the [Submit a new version of an existing
formula][brew] section of the Homebrew docs.

[brew]: https://github.com/Homebrew/brew/blob/master/docs/How-To-Open-a-Homebrew-Pull-Request.md#submit-a-new-version-of-an-existing-formula

An example using v0.1.0 (notice that this uses the sha256 sum of the
tarball):

```bash
$ curl -LOv https://github.com/paltherr/zfun/archive/v0.1.0.tar.gz
$ openssl sha256 v0.1.0.tar.gz
SHA256(v0.1.0.tar.gz)= 1a4e9d14620bf6e53aaf86047e60e31e02a1f600bff1d8dc422a16fa6594f6ce

# Add the --dry-run flag to see the individual steps without executing.
$ brew bump-formula-pr \
  --url=https://github.com/paltherr/zfun/archive/v0.1.0.tar.gz \
  --sha256=1a4e9d14620bf6e53aaf86047e60e31e02a1f600bff1d8dc422a16fa6594f6ce
```
