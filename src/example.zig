const falco = @import("falco");

comptime {
    falco.export_plugin(.{
        .init = init,
        .destroy = destroy,
        .get_required_api_version = get_required_api_version,
        .get_name = get_name,
        .get_description = get_description,
        .get_contact = get_contact,
        .get_version = get_version,
        .get_last_error = get_last_error,
        .capture_listening = .{
            .open = open,
            .close = close,
        },
    });
}

fn init(input: ?*falco.InitInput, rc: ?*falco.Rc) callconv(.C) ?*falco.Plugin {
    _ = input;
    _ = rc;

    return null;
}

fn destroy(s: ?*falco.Plugin) callconv(.C) void {
    _ = s;
}

fn get_required_api_version() callconv(.C) [*:0]const u8 {
    return "0.1.0";
}

fn get_name() callconv(.C) [*:0]const u8 {
    return "Example Plugin";
}

fn get_description() callconv(.C) [*:0]const u8 {
    return "An Example Plugin to test linking features";
}
fn get_contact() callconv(.C) [*:0]const u8 {
    return "Matthew Knight <mattnite@proton.me>";
}
fn get_version() callconv(.C) [*:0]const u8 {
    return "0.0.1";
}
fn get_last_error(s: ?*falco.Plugin) callconv(.C) [*:0]const u8 {
    _ = s;
    return "";
}

fn open(s: ?*falco.Plugin, i: ?*falco.CaptureListenInput) callconv(.C) falco.Rc {
    _ = s;
    _ = i;
    return 0;
}

fn close(s: ?*falco.Plugin, i: ?*falco.CaptureListenInput) callconv(.C) falco.Rc {
    _ = s;
    _ = i;
    return 0;
}
