-record(group, {
    group_id,
    name,
    purpose,
    target = 0,
    members = #{},
    visibility = public,
    version = 0
}).

-record(state, {
    group = undefined
}).