//! The information documenting what symbols are required is contained within
//! `plugin_check_required_symbols()`. Tracking this information between
//! versions will be tedious so this program exists to test each function under
//! `plugin_handle_t.api` against this function and then to generate code that
//! will export the symbols of the plugin.
const std = @import("std");
const c = @cImport({
    @cInclude("plugin/plugin_loader.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    var required_symbols = std.StringArrayHashMap(void).init(allocator);
    defer required_symbols.deinit();

    inline for (@typeInfo(c.plugin_api).Struct.fields) |field| {
        var err_buf: [256]u8 = undefined;
        var handle: c.plugin_handle_t = .{};

        // set struct contents to non zero
        const ptr: [*]u8 = @ptrCast(&handle);
        for (ptr[0..@sizeOf(c.plugin_handle_t)]) |*byte|
            byte.* = 0xFF;

        const ti = @typeInfo(field.type);
        switch (ti) {
            .Struct => |str| {
                inline for (str.fields) |nested_field| {
                    @field(@field(handle.api, field.name), nested_field.name) = null;
                    if (!c.plugin_check_required_symbols(&handle, &err_buf))
                        try required_symbols.put(nested_field.name, {});
                }
            },
            else => {
                @field(handle.api, field.name) = null;
                if (!c.plugin_check_required_symbols(&handle, &err_buf))
                    try required_symbols.put(field.name, {});
            },
        }
    }

    std.log.info("required symbols", .{});
    for (required_symbols.keys()) |required_symbol|
        std.log.info("  plugin_{s}", .{required_symbol});
}
