# About this project

GitHub Actions workflow that patches the official sing-box-for-android
release APKs to add `android.permission.INTERACT_ACROSS_USERS` (so it can be
granted via ADB to allow cross-profile loopback routing on Android 17+),
re-signs them with our own key, and republishes them as releases on this
repo so Obtainium can track and auto-install them.

Background: https://github.com/SagerNet/sing-box/issues/4246

## Git safety

The following git operations are **forbidden**. Ask the human if you think
one is needed.

- `git reset --hard`
- `git clean`
- `git checkout -- .`
- `git rebase`
- `git commit --amend`
