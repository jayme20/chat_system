-module(group_role).

-export([creator/0, admin/0, treasurer/0, member/0, is_admin/1, can_manage_finances/1]).

creator() -> creator.
admin() -> admin.
treasurer() -> treasurer.
member() -> member.

is_admin(creator) -> true;
is_admin(admin) -> true;
is_admin(_) -> false.

can_manage_finances(creator) -> true;
can_manage_finances(admin) -> true;
can_manage_finances(treasurer) -> true;
can_manage_finances(_) -> false.