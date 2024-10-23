const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("plugin/plugin_api.h");
});

const symbol_name_mappings = .{
    // zig fmt: off
    .{                      "init",                      "plugin_init"                      },
    .{                      "destroy",                   "plugin_destroy"                   },
    .{                      "get_required_api_version",  "plugin_get_required_api_version"  },
    .{                      "get_name",                  "plugin_get_name"                  },
    .{                      "get_description",           "plugin_get_description"           },
    .{                      "get_contact",               "plugin_get_contact"               },
    .{                      "get_version",               "plugin_get_version"               },
    .{                      "get_last_error",            "plugin_get_last_error"            },
    .{                      "set_config",                "plugin_set_config"                },
    .{                      "get_metrics",               "plugin_get_metrics"               },

    .{ "event_sourcing",    "get_id",                    "plugin_get_id"                    },
    .{ "event_sourcing",    "get_event_source",          "plugin_get_event_source"          },
    .{ "event_sourcing",    "open",                      "plugin_open"                      },
    .{ "event_sourcing",    "close",                     "plugin_close"                     },
    .{ "event_sourcing",    "list_open_params",          "plugin_list_open_params"          },
    .{ "event_sourcing",    "next_batch",                "plugin_next_batch"                },
    .{ "event_sourcing",    "get_progress",              "plugin_get_progress"              },
    .{ "event_sourcing",    "event_to_string",           "plugin_event_to_string"           },

    .{ "field_extraction",  "get_fields",                "plugin_get_fields"                },
    .{ "field_extraction",  "extract_fields",            "plugin_extract_fields"            },
    .{ "field_extraction",  "get_extract_event_types",   "plugin_get_extract_event_types"   },
    .{ "field_extraction",  "get_extract_event_sources", "plugin_get_extract_event_sources" },

    .{ "event_parsing",     "parse_event",               "plugin_parse_event"               },
    .{ "event_parsing",     "get_parse_event_types",     "plugin_get_parse_event_types"     },
    .{ "event_parsing",     "get_parse_event_sources",   "plugin_get_parse_event_sources"   },

    .{ "async_events",      "get_async_event_sources",   "plugin_get_async_event_sources"   },
    .{ "async_events",      "get_async_events",          "plugin_get_async_events"          },
    .{ "async_events",      "set_async_event_handler",   "plugin_set_async_event_handler"   },

    .{ "capture_listening", "open",                      "plugin_capture_open"              },
    .{ "capture_listening", "close",                     "plugin_capture_close"             },
    // zig fmt: on
};

/// Given a function and it's location within the Interface struct, export a
/// function to its corresponding symbol.
fn export_field(
    comptime func: anytype,
    comptime path: anytype,
) void {
    inline for (symbol_name_mappings) |mapping| {
        inline for (0..path.len) |i| {
            if (!std.mem.eql(u8, path[i], mapping[i]))
                break;
        } else {
            @export(func, .{ .name = mapping[path.len] });
            return;
        }
    } else @compileError(if (path.len == 1)
        std.fmt.comptimePrint("No mapping for {s}", .{path[0]})
    else
        std.fmt.comptimePrint("No mapping for {s}.{s}", .{ path[0], path[1] }));
}

fn export_struct(
    comptime value: anytype,
    comptime name: []const u8,
) void {
    inline for (@typeInfo(@TypeOf(value)).Struct.fields) |field| {
        switch (@typeInfo(field.type)) {
            .Optional => if (@field(value, field.name)) |payload| {
                export_field(payload, .{ name, field.name });
            },
            else => export_field(@field(value, field.name), .{ name, field.name }),
        }
    }
}

pub fn export_plugin(comptime intf: Interface) void {
    const type_info = @typeInfo(Interface);
    inline for (type_info.Struct.fields) |field| {
        switch (@typeInfo(field.type)) {
            .Struct => export_struct(),
            .Optional => |opt| if (@field(intf, field.name)) |payload| switch (@typeInfo(opt.child)) {
                .Struct => export_struct(payload, field.name),
                else => export_field(payload, .{}),
            },
            else => export_field(@field(intf, field.name), .{field.name}),
        }
    }

    const version_str = intf.get_version();
    const required_api_version_str = intf.get_required_api_version();

    // ensure that the required api version and version are both semver at comptime
    const version = std.SemanticVersion.parse(std.mem.span(version_str)) catch
        @compileError(std.fmt.comptimePrint("Failed to parse plugin version as semver: '{s}'", .{version_str}));

    const required_api_version = std.SemanticVersion.parse(std.mem.span(required_api_version_str)) catch
        @compileError(std.fmt.comptimePrint("Failed to parse plugin required_api_version as semver: '{s}'", .{required_api_version_str}));

    // TODO: more checks for suffixes
    _ = version;
    _ = required_api_version;
}

pub const Instance = c.ss_instance_t;
pub const Plugin = c.ss_plugin_t;
pub const AsyncEventHandler = c.ss_plugin_async_event_handler_t;
pub const CaptureListenInput = c.ss_plugin_capture_listen_input;
pub const Event = c.ss_plugin_event;
pub const EventInput = c.ss_plugin_event_input;
pub const EventParseInput = c.ss_plugin_event_parse_input;
pub const FieldExtractInput = c.ss_plugin_field_extract_input;
pub const InitInput = c.ss_plugin_init_input;
pub const Owner = c.ss_plugin_owner_t;
pub const Rc = c.ss_plugin_rc;
pub const SchemaType = c.ss_plugin_schema_type;
pub const SetConfigInput = c.ss_plugin_set_config_input;
pub const Metric = c.ss_plugin_metric;

pub const Interface = struct {
    init: fn (input: ?*InitInput, rc: ?*Rc) callconv(.C) ?*Plugin,
    destroy: fn (s: ?*Plugin) callconv(.C) void,
    get_required_api_version: fn () callconv(.C) [*:0]const u8,
    get_name: fn () callconv(.C) [*:0]const u8,
    get_description: fn () callconv(.C) [*:0]const u8,
    get_contact: fn () callconv(.C) [*:0]const u8,
    get_version: fn () callconv(.C) [*:0]const u8,
    get_last_error: fn (s: ?*Plugin) callconv(.C) [*:0]const u8,
    get_init_schema: ?fn (schema_type: ?*SchemaType) callconv(.C) [*:0]const u8 = null,
    set_config: ?fn(s: ?*Plugin, i: ?*SetConfigInput) Rc = null,
    get_metrics: ?fn(s: ?*Plugin, num_metrics: ?*u32) *Metric = null,

    event_sourcing: ?struct {
        get_id: fn () callconv(.C) u32,
        get_event_source: fn () callconv(.C) [*:0]const u8,
        open: fn (s: ?*Plugin, params: ?[*:0]const u8, rc: ?*Rc) callconv(.C) ?*Instance,
        close: fn (s: ?*Plugin, h: ?*Instance) callconv(.C) void,
        next_batch: fn (s: ?*Plugin, h: ?*Instance, nevts: ?*u32, evts: ?*?*?*Event) callconv(.C) Rc,
        list_open_params: ?fn (s: ?*Plugin, rc: ?*Rc) callconv(.C) [*:0]const u8 = null,
        get_progress: ?fn (s: ?*Plugin, h: ?*Instance, progress_pct: ?*u32) callconv(.C) void = null,
        event_to_string: ?fn (s: ?*Plugin, evt: ?*EventInput) callconv(.C) [*:0]const u8 = null,
    } = null,

    field_extraction: ?struct {
        get_fields: fn () callconv(.C) [*:0]const u8,
        extract_fields: fn (s: ?*Plugin, evt: ?*EventInput, in: ?*FieldExtractInput) callconv(.C) void,
        get_extract_event_types: ?fn (numtypes: ?*u32, s: ?*Plugin) callconv(.C) *u16 = null,
        get_extract_event_sources: ?fn () callconv(.C) [*:0]const u8 = null,
    } = null,

    event_parsing: ?struct {
        parse_event: fn (s: ?*Plugin, evt: ?*EventInput, in: ?*EventParseInput) callconv(.C) void,
        get_parse_event_types: ?fn (numtypes: ?*u32, s: ?*Plugin) callconv(.C) *u16 = null,
        get_parse_event_sources: ?fn () callconv(.C) [*:0]const u8 = null,
    } = null,

    async_events: ?struct {
        get_async_events: fn () callconv(.C) [*:0]const u8,
        set_async_event_handler: fn (s: ?*Plugin, owner: ?*Owner, handler: AsyncEventHandler) callconv(.C) void,
        get_async_event_sources: ?fn () callconv(.C) [*:0]const u8 = null,
    } = null,

    capture_listening: ?struct {
        open: fn (s: ?*Plugin, i: ?*CaptureListenInput) callconv(.C) Rc,
        close: fn (s: ?*Plugin, i: ?*CaptureListenInput) callconv(.C) Rc,
    } = null,
};

test "all" {
    _ = c;
}
