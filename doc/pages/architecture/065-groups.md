# Groups

Astarte supports creating groups of devices in a realm.

Groups are currently useful mainly to provide access control, combining Astarte's [path based
authorization](070-auth.html#authorization) with the fact that devices can be queried with a group
URL. This makes it possible to emit tokens allowing a user to operate only on devices that belong to
a specific group.

Groups can be managed using [`astartectl`](https://github.com/astarte-platform/astartectl) or using
[AppEngine API](/api/index.html?urls.primaryName=AppEngine API). See the [Managing Groups
page](065-managing-groups.html) in the User Guide for some usage examples.

Keep in mind a group is existing as long as there's at least one device in it. Once the last device
is removed from the group, the group does not exist anymore, since groups are a tag (or label) of
devices.
